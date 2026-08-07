const { spawn } = require('child_process');
const fs = require('fs-extra');
const path = require('path');

const specFile = process.argv[2];

if (!specFile) {
    console.error('Usage: yarn test:mockserver <spec-file>');
    process.exit(1);
}

function runCommand(command, args) {
    return new Promise((resolve, reject) => {
        console.log(`> ${command} ${args.join(' ')}`);
        const child = spawn(command, args, { stdio: 'inherit' });

        child.on('close', (code) => {
            if (code === 0) {
                resolve();
            } else {
                reject(new Error(`Command failed with exit code ${code}`));
            }
        });

        child.on('error', (err) => {
            reject(err);
        });
    });
}

async function testContract() {
    try {
        const reportDir = path.join(process.cwd(), 'out');
        await fs.ensureDir(reportDir);
        await runCommand('wiretap', ['-s', specFile, '-x', '-u', 'http://localhost:9090', '--report-file', 'out/wiretap-mockserver.json']);
    } catch (error) {
        console.error(error.message);
        process.exit(1);
    }
}

testContract();
