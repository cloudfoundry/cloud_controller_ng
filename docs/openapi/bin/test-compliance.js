const { spawn } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const net = require('net');
const http = require('http');
const httpProxy = require('http-proxy');

const serverUrl = process.env.CF_API_URL;
const appsDomain = process.env.CF_APPS_DOMAIN;
const specFile = process.argv[2];
const adminUser = process.env.CF_ADMIN_USER;
const adminPassword = process.env.CF_ADMIN_PASSWORD;
const nodeCount = process.env.THREADS || '6';

if (!serverUrl || !specFile || !adminUser || !adminPassword || !appsDomain) {
    console.error('Usage: node bin/test-compliance.js <spec-file>');
    console.error('Please also set CF_API_URL, CF_APPS_DOMAIN, CF_ADMIN_USER, and CF_ADMIN_PASSWORD environment variables.');
    console.error('Optional: TEST_NODES (default: 6) - Number of test nodes to run in parallel');
    process.exit(1);
}

function runCommand(command, args, options = {}) {
    return new Promise((resolve, reject) => {
        console.log(`> ${command} ${args.join(' ')}`);

        const child = spawn(command, args, {
            stdio: options.captureOutput ? ['ignore', 'pipe', 'pipe'] : 'inherit',
            ...options
        });

        // Track the child process for cleanup if needed
        if (options.trackProcess !== false && global.testCompliance_childProcesses) {
            global.testCompliance_childProcesses.push(child);
        }

        let stdout = '';
        let stderr = '';

        if (options.captureOutput) {
            child.stdout.on('data', (data) => {
                const output = data.toString();
                stdout += output;
                if (options.logOutput !== false) {
                    process.stdout.write(output);
                }
            });

            child.stderr.on('data', (data) => {
                const output = data.toString();
                stderr += output;
                if (options.logOutput !== false) {
                    process.stderr.write(output);
                }
            });
        }

        child.on('close', (code) => {
            // Remove from tracking when process closes
            if (global.testCompliance_childProcesses) {
                const index = global.testCompliance_childProcesses.indexOf(child);
                if (index > -1) {
                    global.testCompliance_childProcesses.splice(index, 1);
                }
            }

            if (code === 0) {
                resolve({ code, stdout, stderr });
            } else {
                const error = new Error(`Command failed with exit code ${code}`);
                error.code = code;
                error.stdout = stdout;
                error.stderr = stderr;
                reject(error);
            }
        });

        child.on('error', (err) => {
            // Remove from tracking on error
            if (global.testCompliance_childProcesses) {
                const index = global.testCompliance_childProcesses.indexOf(child);
                if (index > -1) {
                    global.testCompliance_childProcesses.splice(index, 1);
                }
            }

            err.stdout = stdout;
            err.stderr = stderr;
            reject(err);
        });
    });
}

async function checkGoExists() {
    try {
        await runCommand('go', ['version'], { captureOutput: true, logOutput: false });
    } catch (error) {
        console.error('Go is not installed or not in your PATH. Please install Go to run the compliance tests.');
        process.exit(1);
    }
}

async function killOrphanedProcesses() {
    console.log('Checking for orphaned wiretap processes...');
    try {
        // Kill any existing wiretap processes
        const result = await runCommand('pkill', ['-f', 'wiretap'], {
            captureOutput: true,
            logOutput: false,
            trackProcess: false
        });
        if (result.stdout || result.stderr) {
            console.log('Cleaned up orphaned wiretap processes.');
        }
    } catch (error) {
        // pkill returns non-zero exit code when no processes are found, which is fine
        if (error.code !== 1) {
            console.warn(`Warning: Could not check for orphaned processes: ${error.message}`);
        }
    }
}

function waitForPort(port, retries = 30, delay = 2000) {
    return new Promise((resolve, reject) => {
        const tryConnect = (attempt) => {
            const socket = new net.Socket();
            socket.setTimeout(5000);

            socket.once('connect', () => {
                socket.end();
                resolve();
            });

            socket.once('error', (err) => {
                socket.destroy();
                if (err.code === 'ECONNREFUSED' && attempt < retries) {
                    console.log(`Port ${port} not ready, retrying in ${delay}ms (attempt ${attempt + 1}/${retries})...`);
                    setTimeout(() => tryConnect(attempt + 1), delay);
                } else {
                    reject(err);
                }
            });

            socket.once('timeout', () => {
                socket.destroy();
                if (attempt < retries) {
                    console.log(`Port ${port} timeout, retrying in ${delay}ms (attempt ${attempt + 1}/${retries})...`);
                    setTimeout(() => tryConnect(attempt + 1), delay);
                } else {
                    reject(new Error(`Timeout waiting for port ${port}`));
                }
            });

            socket.connect(port, '127.0.0.1');
        };
        tryConnect(0);
    });
}

function createProxyServer() {
    const proxy = httpProxy.createProxyServer({
        timeout: 30000,
        proxyTimeout: 30000
    });
    const target = serverUrl;

    proxy.on('error', (err, req, res) => {
        console.error(`Proxy error: ${err.message}`);
        if (res && !res.headersSent) {
            res.writeHead(502, {
                'Content-Type': 'text/plain'
            });
            res.end('Bad Gateway - Wiretap may not be ready yet');
        }
    });

    const server = http.createServer((req, res) => {
        if (req.url.startsWith('/v2/')) {
            // Always proxy v2 requests to the actual CF API
            proxy.web(req, res, { target, secure: false, changeOrigin: true });
        } else if (req.headers['content-type'] && req.headers['content-type'].includes('multipart/form-data')) {
            // Always proxy multipart requests to the actual CF API
            proxy.web(req, res, { target, secure: false, changeOrigin: true });
        } else {
            // Try to proxy to wiretap first, fall back to direct CF API on failure
            proxy.web(req, res, {
                target: 'http://localhost:9090',
                secure: false,
                timeout: 5000
            }, (proxyErr) => {
                if (proxyErr) {
                    console.log(`Wiretap proxy failed, falling back to direct CF API: ${proxyErr.message}`);
                    // Fallback: proxy directly to CF API
                    proxy.web(req, res, { target, secure: false, changeOrigin: true });
                }
            });
        }
    });

    return server;
}

async function startWiretap(wiretapProxyPort, serverUrl, specFile, reportFile) {
    console.log('Starting wiretap in the background...');
    console.log(`Wiretap UI will be available at http://localhost:9091`);

    // Ensure log directory exists
    const logDir = path.join('out', 'logs');
    await fs.ensureDir(logDir);
    const stdoutLogFile = path.join(logDir, 'wiretap-stdout.log');
    const stderrLogFile = path.join(logDir, 'wiretap-stderr.log');

    return new Promise((resolve, reject) => {
        // Use npx to ensure we get the right wiretap binary
        const wiretapProcess = spawn('npx', ['wiretap', '-p', wiretapProxyPort, '-u', serverUrl, '-s', specFile, '--hard-validation=false', '--stream-report', "--report-filename", reportFile], {
            detached: true,
            stdio: ['ignore', 'pipe', 'pipe'],
            // Create a new process group so we can kill the entire group
            // This ensures child processes of wiretap are also terminated
        });

        // Ensure the process doesn't keep the parent alive
        wiretapProcess.unref();

        let startupOutput = '';
        let startupErrors = '';
        let hasStarted = false;

        // Create write streams for logging
        const stdoutStream = fs.createWriteStream(stdoutLogFile, { flags: 'w' });
        const stderrStream = fs.createWriteStream(stderrLogFile, { flags: 'w' });

        // Log wiretap output for debugging and to files
        wiretapProcess.stdout.on('data', (data) => {
            const output = data.toString();
            startupOutput += output;

            // Log to console (with timestamp)
            const timestamp = new Date().toISOString();
            console.log(`[${timestamp}] wiretap stdout: ${output.trim()}`);

            // Log to file
            stdoutStream.write(`[${timestamp}] ${output}`);

            // Look for the success message indicating wiretap is ready
            if (output.includes('wiretap is online!') && !hasStarted) {
                hasStarted = true;
                resolve(wiretapProcess);
            }
        });

        wiretapProcess.stderr.on('data', (data) => {
            const error = data.toString();
            startupErrors += error;

            // Log to console (with timestamp)
            const timestamp = new Date().toISOString();
            console.error(`[${timestamp}] wiretap stderr: ${error.trim()}`);

            // Log to file
            stderrStream.write(`[${timestamp}] ${error}`);
        });

        wiretapProcess.on('exit', (code, signal) => {
            const timestamp = new Date().toISOString();
            const exitMessage = `wiretap process exited with code ${code}, signal ${signal}`;
            console.log(`[${timestamp}] ${exitMessage}`);

            // Close log streams
            stdoutStream.end();
            stderrStream.end();

            if (!hasStarted) {
                // Create detailed error message with captured output
                let errorMessage = `Wiretap failed to start (exit code: ${code})`;
                if (startupOutput) {
                    errorMessage += `\n\nStdout output:\n${startupOutput}`;
                }
                if (startupErrors) {
                    errorMessage += `\n\nStderr output:\n${startupErrors}`;
                }
                errorMessage += `\n\nFull logs available at:\n- ${stdoutLogFile}\n- ${stderrLogFile}`;

                reject(new Error(errorMessage));
            }
        });

        wiretapProcess.on('error', (error) => {
            const timestamp = new Date().toISOString();
            console.error(`[${timestamp}] Wiretap process error:`, error);

            // Close log streams
            stdoutStream.end();
            stderrStream.end();

            if (!hasStarted) {
                let errorMessage = `Wiretap process error: ${error.message}`;
                if (startupOutput) {
                    errorMessage += `\n\nStdout output:\n${startupOutput}`;
                }
                if (startupErrors) {
                    errorMessage += `\n\nStderr output:\n${startupErrors}`;
                }
                errorMessage += `\n\nFull logs available at:\n- ${stdoutLogFile}\n- ${stderrLogFile}`;

                reject(new Error(errorMessage));
            }
        });

        console.log(`wiretap started with PID: ${wiretapProcess.pid}`);
        console.log(`Wiretap logs will be written to:\n- stdout: ${stdoutLogFile}\n- stderr: ${stderrLogFile}`);

        // Timeout after 30 seconds if wiretap doesn't start
        setTimeout(() => {
            if (!hasStarted) {
                const timestamp = new Date().toISOString();
                console.warn(`[${timestamp}] Wiretap startup timeout - continuing without wiretap monitoring`);

                // Close log streams
                stdoutStream.end();
                stderrStream.end();

                // Log timeout details
                let timeoutMessage = 'Wiretap startup timeout (30 seconds)';
                if (startupOutput) {
                    timeoutMessage += `\n\nStdout output during startup:\n${startupOutput}`;
                }
                if (startupErrors) {
                    timeoutMessage += `\n\nStderr output during startup:\n${startupErrors}`;
                }
                timeoutMessage += `\n\nFull logs available at:\n- ${stdoutLogFile}\n- ${stderrLogFile}`;

                console.warn(timeoutMessage);

                // Don't reject, just resolve with null to continue without wiretap
                resolve(null);
            }
        }, 30000);
    });
}

async function testCompliance() {
    await checkGoExists();
    await killOrphanedProcesses();

    let wiretapProcess, proxyServer;

    // Initialize global child process tracking
    global.testCompliance_childProcesses = [];

    const cleanup = async (signal = 'SIGTERM') => {
        console.log(`\nCleaning up processes due to ${signal}...`);

        // Stop wiretap process and its children
        if (wiretapProcess && wiretapProcess.pid) {
            console.log(`Stopping wiretap process group (PID: ${wiretapProcess.pid})...`);
            try {
                // Kill the entire process group since wiretap was started detached
                process.kill(-wiretapProcess.pid, 'SIGTERM');
                console.log('Wiretap process group terminated.');
            } catch (e) {
                console.warn(`Failed to kill wiretap process group ${wiretapProcess.pid}: ${e.message}`);
                // Try to kill just the main process as fallback
                try {
                    process.kill(wiretapProcess.pid, 'SIGKILL');
                    console.log('Wiretap main process force killed.');
                } catch (e2) {
                    console.error(`Failed to force kill wiretap process ${wiretapProcess.pid}: ${e2.message}`);
                }
            }
        }

        // Stop proxy server
        if (proxyServer) {
            console.log('Stopping proxy server...');
            return new Promise((resolve) => {
                try {
                    proxyServer.close((err) => {
                        if (err) {
                            console.error(`Error closing proxy server: ${err.message}`);
                        } else {
                            console.log('Proxy server stopped.');
                        }
                        resolve();
                    });

                    // Force close after 5 seconds
                    setTimeout(() => {
                        console.warn('Force closing proxy server...');
                        try {
                            proxyServer.closeAllConnections?.();
                        } catch (e) {
                            console.warn(`Error force closing proxy: ${e.message}`);
                        }
                        resolve();
                    }, 5000);
                } catch (e) {
                    console.error(`Failed to stop proxy server: ${e.message}`);
                    resolve();
                }
            });
        }

        // Clean up any other tracked child processes
        const childProcesses = global.testCompliance_childProcesses || [];
        for (const child of childProcesses) {
            if (child && child.pid && !child.killed) {
                try {
                    console.log(`Terminating child process ${child.pid}...`);
                    child.kill('SIGTERM');
                } catch (e) {
                    console.warn(`Failed to terminate child process ${child.pid}: ${e.message}`);
                }
            }
        }

        // Clear the tracking array
        if (global.testCompliance_childProcesses) {
            global.testCompliance_childProcesses.length = 0;
        }
    };

    // Enhanced signal handling
    const signalHandler = (signal) => {
        console.log(`\nReceived ${signal}, initiating cleanup...`);
        cleanup(signal).then(() => {
            console.log('Cleanup completed.');
            process.exit(signal === 'SIGTERM' ? 0 : 1);
        }).catch((err) => {
            console.error(`Cleanup failed: ${err.message}`);
            process.exit(1);
        });
    };

    // Register signal handlers
    process.on('SIGINT', () => signalHandler('SIGINT'));
    process.on('SIGTERM', () => signalHandler('SIGTERM'));
    process.on('SIGHUP', () => signalHandler('SIGHUP'));
    process.on('SIGQUIT', () => signalHandler('SIGQUIT'));

    // Handle uncaught exceptions and unhandled rejections
    process.on('uncaughtException', (err) => {
        console.error('Uncaught Exception:', err);
        cleanup('uncaughtException').then(() => process.exit(1));
    });

    process.on('unhandledRejection', (reason, promise) => {
        console.error('Unhandled Rejection at:', promise, 'reason:', reason);
        cleanup('unhandledRejection').then(() => process.exit(1));
    });

    // Cleanup on normal exit
    process.on('exit', () => {
        console.log('Process exiting, final cleanup...');
        // Note: exit event cannot perform async operations
        if (wiretapProcess?.pid) {
            try {
                process.kill(-wiretapProcess.pid, 'SIGKILL');
            } catch (e) {
                // Ignore errors during final cleanup
            }
        }
    });

    const tempDir = path.join(process.cwd(), '.tmp', 'capi-bara-tests');
    const wiretapProxyPort = 9090;
    const wiretapApiHost = `http://127.0.0.1:9999`;

    try {
        const reportDir = path.join('out');
        await fs.ensureDir(reportDir);
        const reportFile = path.join(reportDir, 'wiretap-report.json');

        // Start wiretap with improved error handling - allow it to fail gracefully
        try {
            wiretapProcess = await startWiretap(wiretapProxyPort, serverUrl, specFile, reportFile);

            if (wiretapProcess) {
                console.log(`Waiting for wiretap to be ready on port ${wiretapProxyPort}...`);
                await waitForPort(wiretapProxyPort);
                console.log('Wiretap is ready.');
            } else {
                console.warn('Continuing without wiretap - tests will run against CF API directly');
            }
        } catch (wiretapError) {
            console.warn(`Failed to start wiretap: ${wiretapError.message}`);
            console.warn('Continuing without wiretap - tests will run against CF API directly');
            wiretapProcess = null;
        }

        console.log('Starting integrated proxy server...');
        proxyServer = createProxyServer();
        proxyServer.listen(9999, () => {
            console.log('Integrated proxy server listening on port 9999');
        });

        console.log('Waiting for proxy server to be ready on port 9999...');
        await waitForPort(9999);
        console.log('Proxy server is ready.');

        // Check if capi-bara-tests repository already exists
        const repoExists = await fs.pathExists(tempDir);
        if (repoExists) {
            console.log('capi-bara-tests repository already exists, skipping clone...');
        } else {
            console.log('Cloning capi-bara-tests repository...');
            await fs.ensureDir(path.dirname(tempDir));
            await runCommand('git', ['clone', '-b', 'allow-local-api', 'https://github.com/cloudfoundry/capi-bara-tests.git', tempDir]);
        }

        console.log('Populating vendor dependencies...');
        await runCommand('go', ['mod', 'vendor'], { cwd: tempDir });

        console.log('Configuring capi-bara-tests to point to wiretap proxy...');
        const integrationConfig = {
            api: wiretapApiHost,
            protocol: wiretapApiHost.startsWith('https') ? 'https' : 'http',
            apps_domain: appsDomain,
            admin_user: adminUser,
            admin_password: adminPassword,
            skip_ssl_validation: true,
            timeout_scale: 5.0,
        };
        const configPath = path.join(tempDir, 'integration_config.json');
        await fs.writeJson(configPath, integrationConfig, { spaces: 2 });

        const testEnv = { ...process.env };
        delete testEnv.CF_API_URL;
        testEnv.CONFIG = configPath;

        console.log(`Running capi-bara-tests with ${nodeCount} nodes...`);

        // Prepare test output logging
        const testLogFile = path.join(reportDir, 'capi-bara-tests.log');
        const testErrorLogFile = path.join(reportDir, 'capi-bara-tests-error.log');

        try {
            const testResult = await runCommand('./bin/test', [`-nodes=${nodeCount}`], {
                cwd: tempDir,
                env: testEnv,
                captureOutput: true
            });

            // Write successful test output to log file
            if (testResult.stdout) {
                await fs.writeFile(testLogFile, testResult.stdout, 'utf8');
                console.log(`Test output logged to: ${testLogFile}`);
            }

            console.log('Tests completed successfully.');
            console.log(`Report file available at: ${reportFile}`);
            process.exit(0);

        } catch (testError) {
            // Enhanced error logging for test failures
            const timestamp = new Date().toISOString();
            console.error(`[${timestamp}] capi-bara-tests failed with exit code: ${testError.code}`);

            // Log test output and errors to files
            if (testError.stdout) {
                await fs.writeFile(testLogFile, testError.stdout, 'utf8');
                console.log(`Test stdout logged to: ${testLogFile}`);
            }

            if (testError.stderr) {
                await fs.writeFile(testErrorLogFile, testError.stderr, 'utf8');
                console.log(`Test stderr logged to: ${testErrorLogFile}`);
            }

            // Provide detailed error information
            console.error('\n=== TEST FAILURE SUMMARY ===');
            console.error(`Exit code: ${testError.code}`);

            if (testError.stdout && testError.stdout.length > 0) {
                console.error('\nLast 50 lines of stdout:');
                const stdoutLines = testError.stdout.split('\n');
                const lastLines = stdoutLines.slice(-50);
                console.error(lastLines.join('\n'));
            }

            if (testError.stderr && testError.stderr.length > 0) {
                console.error('\nStderr output:');
                console.error(testError.stderr);
            }

            console.error(`\nFull test logs available at:\n- stdout: ${testLogFile}\n- stderr: ${testErrorLogFile}`);
            console.error('============================\n');

            throw testError;
        }

    } catch (error) {
        console.error('\n=== COMPLIANCE TEST FAILURE ===');
        console.error('Compliance test failed:');
        console.error(`Error: ${error.message}`);

        if (error.code) {
            console.error(`Exit code: ${error.code}`);
        }

        if (error.stdout) {
            console.error('\nStdout output:');
            console.error(error.stdout);
        }

        if (error.stderr) {
            console.error('\nStderr output:');
            console.error(error.stderr);
        }

        // Check for common wiretap issues and provide helpful suggestions
        if (error.message.includes('wiretap') || error.message.includes('ECONNREFUSED')) {
            console.error('\n=== TROUBLESHOOTING SUGGESTIONS ===');
            console.error('This appears to be a wiretap-related issue. Try:');
            console.error('1. Check if wiretap is properly installed: npx wiretap --version');
            console.error('2. Verify the OpenAPI spec file is valid');
            console.error('3. Check network connectivity to CF API');
            console.error('4. Review wiretap logs in out/logs/ directory');
        }

        console.error('====================================\n');
        process.exit(1);
    }
}

testCompliance();
