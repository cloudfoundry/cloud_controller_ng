#!/usr/bin/env node

const { execSync, exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const path = require('path');
const os = require('os');

const execAsync = promisify(exec);
const WORKER_COUNT = 3; // Reduced from 5 to help with rate limiting
const RATE_LIMIT_DELAY = 10000; // 10 seconds between API calls
const MAX_RETRIES = 10;

const endpoints = fs.readFileSync(path.join(__dirname, 'enpoints.txt'), 'utf-8');
const args = process.argv.slice(2);
const repoIndex = args.findIndex(arg => !arg.startsWith('-'));
const repo = repoIndex !== -1 ? args[repoIndex] : null;
const verbose = args.includes('-v');
const recolor = args.includes('--recolor');

if (!repo) {
    console.error('Please provide a GitHub repository as an argument (e.g., owner/repo).');
    console.error('');
    console.error('Usage:');
    console.error('  node manage_issues.js <owner/repo> [options]');
    console.error('');
    console.error('Options:');
    console.error('  -v              Verbose output');
    console.error('  --recolor       Recolor existing labels');
    console.error('');
    console.error('Examples:');
    console.error('  node manage_issues.js my-org/my-repo');
    console.error('  node manage_issues.js my-org/my-repo -v');
    console.error('  node manage_issues.js my-org/my-repo --recolor');
    process.exit(1);
}

// Helper function to process tasks in parallel with limited concurrency
async function processTasksInParallel(tasks, processingFunction, concurrency = WORKER_COUNT) {
    const results = [];
    const executing = [];

    for (const task of tasks) {
        const promise = processingFunction(task).then(result => {
            executing.splice(executing.indexOf(promise), 1);
            return result;
        }).catch(error => {
            executing.splice(executing.indexOf(promise), 1);
            throw error;
        });

        results.push(promise);
        executing.push(promise);

        if (executing.length >= concurrency) {
            await Promise.race(executing);
        }
    }

    return Promise.allSettled(results);
}

// Rate limiting helper
function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Retry wrapper for GitHub API calls with exponential backoff
async function retryGitHubCommand(command, maxRetries = MAX_RETRIES) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            const result = await execAsync(command);
            return result;
        } catch (error) {
            const isRateLimit = error.message.includes('was submitted too quickly') ||
                error.message.includes('rate limit') ||
                error.message.includes('API rate limit');

            if (isRateLimit && attempt < maxRetries) {
                const delayMs = RATE_LIMIT_DELAY * Math.pow(2, attempt - 1); // Exponential backoff
                console.log(`Rate limit hit, retrying in ${delayMs}ms (attempt ${attempt}/${maxRetries})`);
                await delay(delayMs);
                continue;
            }
            throw error;
        }
    }
} async function getExistingLabels(repo) {
    try {
        const { stdout } = await execAsync(`gh label list --repo ${repo} --json name`);
        const labelsJson = stdout.trim();
        if (!labelsJson) {
            return [];
        }
        return JSON.parse(labelsJson).map(label => label.name);
    } catch (error) {
        console.error(`Failed to fetch labels for repo ${repo}: ${error.message}`);
        return [];
    }
}

async function ensureLabelExists(label, repo, existingLabels) {
    if (!existingLabels.includes(label)) {
        try {
            let color = Math.floor(Math.random() * 16777215).toString(16);
            color = color.padStart(6, '0');
            const command = `gh label create "${label}" --repo ${repo} --color "${color}" --description "Auto-generated label"`;
            if (verbose) console.log(command);
            await retryGitHubCommand(command);
            existingLabels.push(label);
            console.log(`Created label: ${label}`);
            await delay(200); // Small delay between label operations
        } catch (error) {
            if (!error.message.includes("already exists")) {
                console.error(`Failed to create label ${label}: ${error.message}`);
            }
        }
    }
}

// Extract resource group from path more safely
function extractResourceGroup(endpointPath) {
    const pathParts = endpointPath.split('?')[0].split('/').filter(part => part);
    // Skip 'v3' and get the next meaningful part
    if (pathParts.length > 1 && pathParts[0] === 'v3') {
        let resourcePart = pathParts[1];
        // Handle admin paths
        if (resourcePart === 'admin' && pathParts.length > 2) {
            resourcePart = pathParts[2];
        }
        return resourcePart || 'unknown';
    }
    return pathParts[0] || 'unknown';
}

// Build all tasks and labels
function buildTasksAndLabels() {
    const allLabels = new Set();
    const tasks = [];

    endpoints.split('\n').forEach(line => {
        const trimmedLine = line.trim();
        if (!trimmedLine) return;

        const [method, endpointPath] = trimmedLine.split(' ');
        if (!method || !endpointPath) return;

        const aspects = getAspects();
        aspects.forEach(aspect => {
            allLabels.add("OpenAPI");
            allLabels.add("Quality Check");
            allLabels.add(`Method: ${method}`);
            allLabels.add(`Aspect: ${aspect.title}`);
            const resourceGroup = extractResourceGroup(endpointPath);
            allLabels.add(`Resource: ${resourceGroup}`);
            tasks.push({ method, path: endpointPath, aspect });
        });
    });

    return { allLabels: Array.from(allLabels), tasks };
}


async function processTask(task, repo, verbose) {
    const { method, path: endpointPath, aspect } = task;
    const endpointName = `${method} ${endpointPath}`;
    const aspectTitle = aspect.title.toLowerCase().replace(/ /g, '-');
    const issueId = `<!-- ID: ${endpointName}-${aspectTitle} -->`;
    const title = `SpecCheck: ${endpointName} - ${aspect.title}`;
    const body = `Check and validate the correctness of the openapi specification for \`${endpointName}\`\n\n**Aspect:** ${aspect.body}\n\n**Details:**\n${aspect.details}\n\n${issueId}`;
    const resourceGroup = extractResourceGroup(endpointPath);
    const labels = ["OpenAPI", "Quality Check", `Method: ${method}`, `Aspect: ${aspect.title}`, `Resource: ${resourceGroup}`];

    try {
        const searchCommand = `gh issue list --repo ${repo} --search "in:body '${issueId}'" --json number,state,labels`;
        if (verbose) console.log(searchCommand);
        const { stdout } = await retryGitHubCommand(searchCommand);
        const existingIssues = JSON.parse(stdout.trim());

        if (existingIssues.length > 0) {
            const issue = existingIssues[0];
            if (issue.state === 'OPEN') {
                // Update issue body using temporary file approach
                const tempFile = path.join(os.tmpdir(), `issue-body-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.txt`);
                fs.writeFileSync(tempFile, body);

                try {
                    const editCommand = `gh issue edit ${issue.number} --repo ${repo} --title ${JSON.stringify(title)} --body-file "${tempFile}"`;
                    if (verbose) console.log(editCommand);
                    await retryGitHubCommand(editCommand);

                    const issueLabels = issue.labels.map(l => l.name);
                    const labelsToAdd = labels.filter(l => !issueLabels.includes(l));
                    const labelsToRemove = issueLabels.filter(l => !labels.includes(l));

                    if (labelsToAdd.length > 0) {
                        const addLabelCommand = `gh issue edit ${issue.number} --repo ${repo} --add-label "${labelsToAdd.join(',')}"`;
                        if (verbose) console.log(addLabelCommand);
                        await retryGitHubCommand(addLabelCommand);
                    }
                    if (labelsToRemove.length > 0) {
                        const removeLabelCommand = `gh issue edit ${issue.number} --repo ${repo} --remove-label "${labelsToRemove.join(',')}"`;
                        if (verbose) console.log(removeLabelCommand);
                        await retryGitHubCommand(removeLabelCommand);
                    }

                    console.log(`✓ Updated issue for ${endpointName} - ${aspect.title}`);
                } finally {
                    // Clean up temp file
                    if (fs.existsSync(tempFile)) {
                        fs.unlinkSync(tempFile);
                    }
                }
            } else {
                console.log(`⊝ Skipping closed issue for ${endpointName} - ${aspect.title}`);
            }
        } else {
            // Create new issue using temporary file approach
            const tempFile = path.join(os.tmpdir(), `issue-body-${Date.now()}-${Math.random().toString(36).substr(2, 9)}.txt`);
            fs.writeFileSync(tempFile, body);

            try {
                const createCommand = `gh issue create --repo ${repo} --title ${JSON.stringify(title)} --body-file "${tempFile}" --label "${labels.join(',')}"`;
                if (verbose) console.log(createCommand);
                await retryGitHubCommand(createCommand);
                console.log(`✓ Created issue for ${endpointName} - ${aspect.title}`);

                // Add a small delay after creating an issue to help with rate limiting
                await delay(500);
            } finally {
                // Clean up temp file
                if (fs.existsSync(tempFile)) {
                    fs.unlinkSync(tempFile);
                }
            }
        }
    } catch (error) {
        console.error(`✗ Failed to process issue for ${endpointName} - ${aspect.title}: ${error.message}`);
        throw error; // Re-throw to handle in calling function
    }
}

// Main execution function
async function main() {
    try {
        console.log(`Starting issue management for repository: ${repo}`);
        console.log(`Using ${WORKER_COUNT} parallel workers with rate limiting`);
        console.log(`Rate limit delay: ${RATE_LIMIT_DELAY}ms, Max retries: ${MAX_RETRIES}`);

        // Check if gh CLI is available
        try {
            await execAsync('gh --version');
        } catch (error) {
            console.error('Error: GitHub CLI (gh) is not installed or not in PATH');
            console.error('Please install it from: https://cli.github.com/');
            process.exit(1);
        }

        // Verify repository access
        try {
            await execAsync(`gh repo view ${repo} --json name`);
        } catch (error) {
            console.error(`Error: Cannot access repository ${repo}`);
            console.error('Please check that the repository exists and you have access to it');
            process.exit(1);
        }

        // Get existing labels
        console.log('Fetching existing labels...');
        const existingLabels = await getExistingLabels(repo);

        // Build tasks and labels
        console.log('Building tasks and labels...');
        const { allLabels, tasks } = buildTasksAndLabels();
        console.log(`Found ${tasks.length} tasks to process`);

        // Handle recoloring if requested
        if (recolor) {
            console.log('Recoloring existing labels...');
            const recolorTasks = existingLabels.map(label => async () => {
                try {
                    let color = Math.floor(Math.random() * 16777215).toString(16);
                    color = color.padStart(6, '0');
                    const command = `gh label edit "${label}" --repo ${repo} --color "${color}"`;
                    if (verbose) console.log(command);
                    await retryGitHubCommand(command);
                    console.log(`Recolored label: ${label}`);
                    await delay(200); // Small delay between operations
                } catch (error) {
                    console.error(`Failed to recolor label ${label}: ${error.message}`);
                }
            });

            await processTasksInParallel(recolorTasks, task => task(), WORKER_COUNT);
        }

        // Ensure all labels exist
        console.log('Ensuring all required labels exist...');
        const labelTasks = allLabels.map(label =>
            () => ensureLabelExists(label, repo, existingLabels)
        );
        const labelResults = await processTasksInParallel(labelTasks, task => task(), WORKER_COUNT);
        const labelErrors = labelResults.filter(r => r.status === 'rejected').length;
        if (labelErrors > 0) {
            console.warn(`Warning: ${labelErrors} label operations failed`);
        }

        // Process all issue tasks
        console.log(`Processing ${tasks.length} issue tasks with ${WORKER_COUNT} workers...`);
        let processed = 0;
        let errors = 0;

        const issueTasks = tasks.map(task => async () => {
            try {
                await processTask(task, repo, verbose);
                processed++;
                if (processed % 10 === 0) {
                    console.log(`Progress: ${processed}/${tasks.length} tasks completed`);
                }
                return { success: true };
            } catch (error) {
                errors++;
                return { success: false, error: error.message };
            }
        });

        const issueResults = await processTasksInParallel(issueTasks, task => task(), WORKER_COUNT);

        // Count actual successes and failures
        const successful = issueResults.filter(r => r.status === 'fulfilled' && r.value?.success).length;
        const failed = issueResults.length - successful;

        console.log(`\n=== Summary ===`);
        console.log(`Total tasks: ${tasks.length}`);
        console.log(`Successfully processed: ${successful}`);
        console.log(`Errors: ${failed}`);
        console.log(`Success rate: ${((successful / tasks.length) * 100).toFixed(1)}%`);

        if (failed > 0) {
            console.warn(`Warning: ${failed} tasks failed. Check the error messages above.`);
            process.exit(1);
        } else {
            console.log('✓ All tasks completed successfully!');
        }

    } catch (error) {
        console.error(`Fatal error: ${error.message}`);
        process.exit(1);
    }
}

// Run main function
main();


function getAspects() {
    return [
        {
            title: 'Path',
            body: 'Verify the endpoint path and its parameters.',
            details: `
- [ ] **Path Correctness**: Ensure the path is correct and follows RESTful conventions. For example, for a resource, the path should be plural (e.g., \`/v3/apps\`).
- [ ] **Path Templating**: Check that path parameters are correctly defined using curly braces (e.g., \`/v3/apps/{guid}\`).
- [ ] **Parameter Definition**: Verify that each path parameter is defined in the \`parameters\` section of the Path Item Object.
- [ ] **Character Encoding**: Ensure that path parameter values do not contain unescaped characters like \`/\`, \`?\`, or \`#\`.`
        },
        {
            title: 'Request Schema',
            body: 'Verify the request body schema.',
            details: `
- [ ] **Schema Validation**: Validate the request body schema against the actual implementation.
- [ ] **Data Types**: Check for correct data types (e.g., \`string\`, \`number\`, \`boolean\`, \`array\`, \`object\`).
- [ ] **Required Fields**: Ensure all required fields are marked as such in the schema.
- [ ] **Constraints**: Verify constraints like \`minimum\`, \`maximum\`, \`minLength\`, \`maxLength\`, and \`pattern\`.
- [ ] **Examples**: Ensure that examples provided in the schema are valid and helpful.`
        },
        {
            title: 'Request Parameters',
            body: 'Verify the request parameters for the endpoint.',
            details: `
- [ ] **Parameter Naming**: Check for consistent and descriptive parameter names.
- [ ] **Parameter Location**: Verify the parameter location (\`in\`: \`query\`, \`header\`, \`path\`, \`cookie\`).
- [ ] **Required Flag**: Ensure the \`required\` flag is set correctly for each parameter.
- [ ] **Schema Definition**: Verify that each parameter has a well-defined schema with the correct type and format.
- [ ] **Style and Explode**: Check the \`style\` and \`explode\` keywords for proper serialization of complex parameters.`
        },
        {
            title: 'Request Headers',
            body: 'Verify the request headers.',
            details: `
- [ ] **Standard Headers**: Check for the presence of standard headers like \`Content-Type\` and \`Authorization\`.
- [ ] **Custom Headers**: Verify that any custom headers are correctly defined and documented.
- [ ] **Case-Insensitivity**: Remember that header names are case-insensitive as per RFC7230.`
        },
        {
            title: 'Response Body',
            body: 'Verify the response body for all possible response codes.',
            details: `
- [ ] **Schema per Response Code**: Validate the schema for the body of each response code (e.g., \`200\`, \`201\`, \`404\`).
- [ ] **Data Types and Structures**: Check for correct data types and object structures in the response.
- [ ] **Examples**: Ensure that examples are accurate, helpful, and match the defined schema.
- [ ] **Links Object**: Verify that the \`links\` object provides correct and useful URLs to related resources.`
        },
        {
            title: 'Response Headers',
            body: 'Verify the response headers.',
            details: `
- [ ] **Standard Headers**: Check for standard response headers like \`Content-Type\`, \`ETag\`, and \`Location\`.
- [ ] **Custom Headers**: Verify that custom headers are correctly defined in the \`headers\` section of the Response Object.
- [ ] **Rate Limiting Headers**: If applicable, check for headers like \`X-Rate-Limit-Limit\`, \`X-Rate-Limit-Remaining\`, and \`X-Rate-Limit-Reset\`.`
        },
        {
            title: 'Response Codes',
            body: 'Verify the HTTP response status codes.',
            details: `
- [ ] **Success Codes**: Ensure all possible success codes are documented (e.g., \`200 OK\`, \`201 Created\`, \`202 Accepted\`, \`204 No Content\`).
- [ ] **Error Codes**: Ensure that appropriate error codes are used for client and server errors (\`4xx\` and \`5xx\` ranges).
- [ ] **Default Response**: Check if a \`default\` response is defined for unexpected errors.`
        },
        {
            title: 'Error Handling',
            body: 'Verify the error responses for the endpoint.',
            details: `
- [ ] **Error Response Schema**: Ensure a consistent error response body schema is used across all error responses.
- [ ] **Error Codes and Titles**: Verify that the error \`code\` and \`title\` are informative and consistent.
- [ ] **Error Details**: Check that the \`detail\` message provides a clear explanation of the error.`
        },
        {
            title: 'Summary and Description',
            body: 'Verify the summary and description for the operation.',
            details: `
- [ ] **Clarity and Accuracy**: Check for clarity, accuracy, and completeness in the summary and description.
- [ ] **Concise Summary**: Ensure the \`summary\` provides a short, easy-to-understand overview of the operation.
- [ ] **Detailed Description**: Verify the \`description\` provides enough detail, including any specific behaviors or constraints.
- [ ] **GithubMarkdown Syntax**: Ensure that GithubMarkdown syntax is used correctly for rich text representation.`
        },
        {
            title: 'Tags',
            body: 'Verify the tags associated with the operation.',
            details: `
- [ ] **Relevance**: Ensure tags are relevant to the operation and group it logically with other operations.
- [ ] **Consistency**: Check for consistent use of tags across the API.
- [ ] **Declaration**: Verify that tags used in operations are declared in the global \`tags\` section of the OpenAPI document.`
        },
        {
            title: 'Security',
            body: 'Verify the security requirements for the endpoint.',
            details: `
- [ ] **Security Scheme**: Verify that the correct security scheme is applied (e.g., \`OAuth2\`, \`API Key\`).
- [ ] **Scopes**: Ensure that the required OAuth2 scopes are correctly defined for the operation.
- [ ] **Permissions**: Cross-reference with the Cloud Foundry documentation to ensure the roles and permissions required for the endpoint are accurately reflected.`
        },
    ];
}
