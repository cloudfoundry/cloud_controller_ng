const fs = require('fs-extra');
const path = require('path');
const yaml = require('js-yaml');

const version = process.argv[2];

if (!version) {
    console.error('Please provide a version number.');
    process.exit(1);
}

const apisDir = path.join(process.cwd(), 'apis', 'cf');
const latestDir = path.join(apisDir, 'latest');
const versionDir = path.join(apisDir, version);

async function createVersion() {
    console.log(`Creating version ${version}...`);

    // Copy latest directory to new version directory
    await fs.copy(latestDir, versionDir);
    console.log(`Copied 'latest' to '${version}'`);

    // Update redocly.yaml
    const redoclyConfigFile = path.join(process.cwd(), 'redocly.yaml');
    const redoclyConfig = yaml.load(await fs.readFile(redoclyConfigFile, 'utf8'));

    if (!redoclyConfig.apis) {
        redoclyConfig.apis = {};
    }

    const apiName = `cf@${version}`;
    redoclyConfig.apis[apiName] = {
        root: `apis/cf/${version}/openapi.yaml`,
    };

    await fs.writeFile(redoclyConfigFile, yaml.dump(redoclyConfig));
    console.log(`Updated redocly.yaml with version ${version}`);

    // Update openapi.yaml with new version
    const openapiFile = path.join(versionDir, 'openapi.yaml');
    const openapiContent = await fs.readFile(openapiFile, 'utf8');
    const updatedOpenapiContent = openapiContent.replace(/version: latest/g, `version: ${version}`);
    await fs.writeFile(openapiFile, updatedOpenapiContent);
    console.log(`Updated openapi.yaml in '${version}' directory with new version`);

    console.log('Version creation complete.');
}

createVersion().catch(err => {
    console.error(err);
    process.exit(1);
});
