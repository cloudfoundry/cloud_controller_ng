/**
 * Wiretap violation summarizer.
 *
 * Reduces a wiretap report (out/wiretap-report.json) to an actionable summary:
 * which endpoints are failing, why, and — critically — whether a violation is a
 * defect in the OpenAPI spec or genuine API non-compliance.
 *
 * Usage:
 *   node bin/summarize-violations.js <report-file> [options]
 *
 * Options:
 *   --top N      How many rows per table (default 20, use 0 for all)
 *   --json       Emit machine-readable JSON instead of markdown
 *   --fields     Include the field-level schema error breakdown
 *
 * Example:
 *   node bin/summarize-violations.js out/wiretap-report.json --fields | tee out/violations.md
 *
 * Uses only Node.js built-ins.
 */

'use strict';

const fs = require('fs');

// ── Report loading ───────────────────────────────────────────────────────────

/**
 * wiretap writes either a single JSON array (--stream-report finalised) or
 * newline-delimited JSON objects (streaming, often named .jsonl). Accept both,
 * and tolerate a trailing comma / unterminated array from a crashed run.
 */
function loadReport(file) {
    const text = fs.readFileSync(file, 'utf8').trim();
    if (!text) return [];

    try {
        const parsed = JSON.parse(text);
        return Array.isArray(parsed) ? parsed : [parsed];
    } catch (_) {
        // Fall through to line-by-line.
    }

    const records = [];
    for (const line of text.split('\n')) {
        const trimmed = line.trim().replace(/,$/, '');
        if (!trimmed || trimmed === '[' || trimmed === ']') continue;
        try {
            records.push(JSON.parse(trimmed));
        } catch (_) {
            // Skip an unparseable line rather than losing the whole report.
        }
    }
    if (records.length === 0) {
        throw new Error(`Could not parse ${file} as JSON or JSONL`);
    }
    return records;
}

// ── Classification ───────────────────────────────────────────────────────────

/**
 * A "schema render failure" means wiretap could not even build the validator
 * from the spec, so nothing about the live API was actually checked. That is a
 * spec bug, and counting it as an API violation badly skews the numbers.
 */
function isSpecDefect(rec) {
    const reason = rec.reason || '';
    return /schema render failure|failed to render|circular reference/i.test(reason);
}

const GUID_RE = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;

/** Collapse instance-specific detail so identical causes group together. */
function signature(reason) {
    return (reason || '(no reason given)')
        .replace(GUID_RE, '{guid}')
        .replace(/'\d{3}'/g, "'{status}'")
        .replace(/\s+/g, ' ')
        .trim();
}

function endpointOf(rec) {
    const method = rec.requestMethod || '?';
    const path = rec.specPath || rec.requestPath || '(unmatched)';
    return `${method} ${path}`;
}

// ── Aggregation ──────────────────────────────────────────────────────────────

function tally(records, keyFn) {
    const counts = new Map();
    for (const rec of records) {
        const key = keyFn(rec);
        counts.set(key, (counts.get(key) || 0) + 1);
    }
    return [...counts.entries()].sort((a, b) => b[1] - a[1] || String(a[0]).localeCompare(String(b[0])));
}

function fieldErrors(records) {
    const counts = new Map();
    for (const rec of records) {
        if (!Array.isArray(rec.validationErrors)) continue;
        for (const err of rec.validationErrors) {
            if (!err || typeof err !== 'object') continue;
            // 0.4.x gives a string fieldPath; 0.7.x may give instancePath as an
            // array of segments. Normalise both, collapsing array indices.
            const raw = err.fieldPath || err.instancePath || err.location || '(unknown)';
            const where = (Array.isArray(raw)
                ? '$.' + raw.map(seg => (/^\d+$/.test(String(seg)) ? '[*]' : String(seg))).join('.')
                : String(raw)
            ).replace(/\[\d+\]/g, '[*]').replace(/\.\[\*\]/g, '[*]');
            const key = `${where} — ${signature(err.reason)}`;
            counts.set(key, (counts.get(key) || 0) + 1);
        }
    }
    return [...counts.entries()].sort((a, b) => b[1] - a[1]);
}

/** Extract every schema named in a circular-reference failure. */
function circularRefs(records) {
    const counts = new Map();
    for (const rec of records) {
        const matches = (rec.reason || '').match(/circular reference: `([^`]+)`/g) || [];
        for (const m of matches) {
            const name = m.replace(/^circular reference: `/, '').replace(/`$/, '');
            counts.set(name, (counts.get(name) || 0) + 1);
        }
    }
    return [...counts.entries()].sort((a, b) => b[1] - a[1]);
}

function summarize(records) {
    const specDefects = records.filter(isSpecDefect);
    const nonCompliance = records.filter(r => !isSpecDefect(r));

    return {
        total: records.length,
        specDefectCount: specDefects.length,
        nonComplianceCount: nonCompliance.length,
        specName: (records.find(r => r.specName) || {}).specName || '(unknown)',
        byType: tally(records, r => `${r.validationType || '?'} / ${r.validationSubType || '?'}`),
        byEndpoint: tally(records, endpointOf),
        specDefectCauses: tally(specDefects, r => signature(r.reason)),
        circularRefs: circularRefs(specDefects),
        nonComplianceCauses: tally(nonCompliance, r => signature(r.reason)),
        nonComplianceEndpoints: tally(nonCompliance, endpointOf),
        fields: fieldErrors(nonCompliance),
    };
}

// ── Rendering ────────────────────────────────────────────────────────────────

function truncate(str, max) {
    const s = String(str).replace(/\|/g, '\\|');
    return s.length > max ? s.slice(0, max - 1) + '…' : s;
}

function table(rows, headers, limit) {
    if (rows.length === 0) return ['_none_', ''];
    const shown = limit > 0 ? rows.slice(0, limit) : rows;
    const out = [
        `| ${headers.join(' | ')} |`,
        `|${headers.map(() => '---').join('|')}|`,
    ];
    for (const [key, count] of shown) {
        out.push(`| ${count} | \`${truncate(key, 160)}\` |`);
    }
    if (shown.length < rows.length) {
        out.push(`| … | _${rows.length - shown.length} more (use \`--top 0\`)_ |`);
    }
    out.push('');
    return out;
}

function renderMarkdown(s, opts) {
    const pct = n => s.total > 0 ? ((n / s.total) * 100).toFixed(1) : '0.0';
    const lines = [
        '## OpenAPI Compliance Violation Summary',
        '',
        `**Spec:** \`${s.specName}\`  `,
        `**Total violations:** ${s.total}`,
        '',
        `- **Spec defects:** ${s.specDefectCount} (${pct(s.specDefectCount)}%) — the schema could not be rendered, so the live API was never actually validated. Fix these first; they mask real results.`,
        `- **API non-compliance:** ${s.nonComplianceCount} (${pct(s.nonComplianceCount)}%) — the API genuinely diverged from the spec.`,
        '',
        '### Violations by type',
        '',
        ...table(s.byType, ['Count', 'Type / subtype'], 0),
        '### Spec defects — circular references to break',
        '',
        ...table(s.circularRefs, ['Hits', 'Schema'], opts.top),
        '### Spec defects — root causes',
        '',
        ...table(s.specDefectCauses, ['Count', 'Cause'], opts.top),
        '### API non-compliance — root causes',
        '',
        ...table(s.nonComplianceCauses, ['Count', 'Cause'], opts.top),
        '### API non-compliance — by endpoint',
        '',
        ...table(s.nonComplianceEndpoints, ['Count', 'Endpoint'], opts.top),
        '### All violations by endpoint',
        '',
        ...table(s.byEndpoint, ['Count', 'Endpoint'], opts.top),
    ];

    if (opts.fields) {
        lines.push('### Field-level schema errors (non-compliance only)', '');
        lines.push(...table(s.fields, ['Count', 'Field — reason'], opts.top));
    }

    return lines.join('\n');
}

// ── Main ─────────────────────────────────────────────────────────────────────

function main() {
    const argv = process.argv.slice(2);
    const file = argv.find(a => !a.startsWith('--'));
    const opts = {
        json: argv.includes('--json'),
        fields: argv.includes('--fields'),
        top: 20,
    };
    const topIdx = argv.indexOf('--top');
    if (topIdx !== -1 && argv[topIdx + 1] !== undefined) {
        opts.top = parseInt(argv[topIdx + 1], 10) || 0;
    }

    if (!file) {
        console.error('Usage: node bin/summarize-violations.js <report-file> [--top N] [--json] [--fields]');
        process.exit(1);
    }
    if (!fs.existsSync(file)) {
        console.error(`Report file not found: ${file}`);
        process.exit(1);
    }

    const summary = summarize(loadReport(file));

    if (opts.json) {
        const asObj = pairs => pairs.map(([key, count]) => ({ key, count }));
        console.log(JSON.stringify({
            spec: summary.specName,
            total: summary.total,
            specDefects: summary.specDefectCount,
            nonCompliance: summary.nonComplianceCount,
            byType: asObj(summary.byType),
            byEndpoint: asObj(summary.byEndpoint),
            specDefectCauses: asObj(summary.specDefectCauses),
            circularRefs: asObj(summary.circularRefs),
            nonComplianceCauses: asObj(summary.nonComplianceCauses),
            fields: asObj(summary.fields),
        }, null, 2));
    } else {
        console.log(renderMarkdown(summary, opts));
    }

    if (process.env.GITHUB_STEP_SUMMARY && !opts.json) {
        fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, '\n' + renderMarkdown(summary, opts) + '\n');
    }
}

main();
