const fs = require('fs-extra');
const path = require('path');
const { spawn } = require('child_process');

const apisDir = path.join(process.cwd(), 'apis', 'cf');
const distDir = path.join(process.cwd(), 'dist');

function runCommand(command, args, options = {}) {
    return new Promise((resolve) => {
        const cmd = `${command} ${args.join(' ')}`;
        const cwd = options.cwd || process.cwd();
        console.log(`> ${cmd}${options.cwd ? ` (in ${options.cwd})` : ''}`);
        const child = spawn(command, args, { ...options });

        let stdout = '';
        let stderr = '';

        child.stdout.on('data', (data) => {
            stdout += data.toString();
        });

        child.stderr.on('data', (data) => {
            stderr += data.toString();
        });

        child.on('close', (code) => {
            resolve({
                command: cmd,
                code,
                stdout,
                stderr,
            });
        });

        child.on('error', (err) => {
            resolve({
                command: cmd,
                code: 1,
                stdout: '',
                stderr: err.message,
            });
        });
    });
}

async function build() {
    await fs.ensureDir(distDir);

    const apiVersions = await fs.readdir(apisDir);

    const promises = [];
    const scalarConfigs = [];

    for (const version of apiVersions) {
        const apiVersionDir = path.join(apisDir, version);
        const stats = await fs.stat(apiVersionDir);

        if (stats.isDirectory()) {
            const openapiFile = path.join(apiVersionDir, 'openapi.yaml');
            if (await fs.pathExists(openapiFile)) {
                const distApiDir = path.join(distDir, version);
                await fs.ensureDir(distApiDir);

                const outputFile = path.join(distApiDir, 'openapi.yaml');
                // Run redocly bundle from the API directory
                promises.push(runCommand('redocly', ['bundle', 'openapi.yaml', '-o', path.resolve(outputFile)], {
                    cwd: apiVersionDir
                }).then(async (result) => {
                    return result;
                }));

                const config = {
                    title: `Cloud Foundry V3 (CAPI ${version})`,
                    slug: `cf-api-${version}`,
                    url: `${version}/openapi.yaml`,
                };

                if (version === 'latest') {
                    config.default = true;
                }

                scalarConfigs.push(config);
            }
        }
    }

    const results = await Promise.all(promises);

    let hasErrors = false;
    for (const result of results) {
        if (result.code !== 0) {
            hasErrors = true;
            console.error(`\nCommand failed: ${result.command}`);
            if (result.stdout) {
                console.log(result.stdout);
            }
            if (result.stderr) {
                console.error(result.stderr);
            }
        } else {
            console.log(`\nCommand successful: ${result.command}`);
            if (result.stdout) {
                console.log(result.stdout);
            }
            if (result.stderr) {
                console.error(result.stderr);
            }
        }
    }

    if (hasErrors) {
        console.error('\nBuild failed.');
        process.exit(1);
    }

    const indexHtml = `
<!doctype html>
<html>

<head>
    <title>Scalar API Reference</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
</head>

<body>
    <div id="app"></div>

    <!-- Load the Script -->
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>

    <!-- Initialize the Scalar API Reference -->
    <script>
        Scalar.createApiReference('#app', ${JSON.stringify(scalarConfigs, null, 12)})
    </script>
</body>

</html>
`;

    await fs.writeFile(path.join(distDir, 'index.html'), indexHtml);
    console.log('Successfully generated dist/index.html');
}

build().catch(err => {
    console.error(err);
    process.exit(1);
});