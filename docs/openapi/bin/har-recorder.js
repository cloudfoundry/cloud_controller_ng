/**
 * HAR 1.2 recorder for the compliance proxy.
 *
 * Captures request/response pairs as they pass through, so a single expensive
 * BARA run yields a replayable corpus. Future spec changes can then be checked
 * with `wiretap -z <har> -g -j /` in seconds instead of re-running the suite.
 *
 * Two things make the corpus practical rather than enormous:
 *   - Deduplication. A run produces hundreds of identical `POST /v3/roles`
 *     exchanges; only `maxPerKey` per (method, normalised path, status) are kept.
 *   - Scrubbing. Tokens and credentials never reach the file, so the corpus is
 *     safe to commit and diff in review.
 *
 * Uses only Node.js built-ins.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const GUID_RE = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;

// Headers whose values must never be written to disk.
const SENSITIVE_HEADER_RE = /^(authorization|cookie|set-cookie|proxy-authorization)$|token|secret|password|credential/i;

// Content types we record as metadata only — binary or opaque payloads add
// megabytes and are worthless for schema validation.
const SKIP_BODY_RE = /^(multipart\/|application\/octet-stream|application\/zip|application\/x-tar|image\/|video\/|audio\/)/i;

class HarRecorder {
    constructor(opts = {}) {
        this.file = opts.file || path.join('out', 'traffic.har');
        this.maxPerKey = opts.maxPerKey === undefined ? 1 : opts.maxPerKey;
        this.maxBodyBytes = opts.maxBodyBytes === undefined ? 256 * 1024 : opts.maxBodyBytes;
        this.entries = [];
        this.counts = new Map();
        this.skipped = 0;
    }

    /** Collapse instance-specific path segments so repeats share a key. */
    static normalisePath(url) {
        const pathOnly = String(url).split('?')[0];
        return pathOnly.replace(GUID_RE, '{guid}');
    }

    /**
     * Normalise the query string for keying. Parameter values are kept — a
     * `?include=space` response carries an `included` block that `?include=org`
     * does not, so collapsing them would lose the coverage the corpus exists
     * for. Only GUIDs are masked, which is what actually varies per run.
     */
    static normaliseQuery(url) {
        const qs = String(url).split('?')[1];
        if (!qs) return '';
        return '?' + qs.split('&').filter(Boolean).sort()
            .join('&').replace(GUID_RE, '{guid}');
    }

    static headerList(headers, scrub) {
        const out = [];
        for (const [name, value] of Object.entries(headers || {})) {
            const values = Array.isArray(value) ? value : [value];
            for (const v of values) {
                out.push({
                    name,
                    value: scrub && SENSITIVE_HEADER_RE.test(name) ? 'REDACTED' : String(v),
                });
            }
        }
        return out;
    }

    static queryList(url) {
        const qs = String(url).split('?')[1];
        if (!qs) return [];
        return qs.split('&').filter(Boolean).map(pair => {
            const eq = pair.indexOf('=');
            const raw = eq === -1 ? [pair, ''] : [pair.slice(0, eq), pair.slice(eq + 1)];
            const decode = s => { try { return decodeURIComponent(s); } catch (_) { return s; } };
            return { name: decode(raw[0]), value: decode(raw[1]) };
        });
    }

    contentTypeOf(headers) {
        for (const [k, v] of Object.entries(headers || {})) {
            if (k.toLowerCase() === 'content-type') return String(Array.isArray(v) ? v[0] : v);
        }
        return '';
    }

    bodyText(buf, headers) {
        if (!buf || buf.length === 0) return null;
        if (SKIP_BODY_RE.test(this.contentTypeOf(headers))) return null;
        if (buf.length > this.maxBodyBytes) return null;
        const text = buf.toString('utf8');
        // Reject anything that did not survive a utf8 round-trip — it is binary.
        return Buffer.byteLength(text, 'utf8') === buf.length ? text : null;
    }

    /**
     * Offer an exchange to the recorder. Returns true if it was kept.
     */
    record(ex) {
        const key = `${ex.method} ${HarRecorder.normalisePath(ex.url)}${HarRecorder.normaliseQuery(ex.url)} ${ex.status}`;
        const seen = this.counts.get(key) || 0;
        if (this.maxPerKey > 0 && seen >= this.maxPerKey) {
            this.skipped++;
            return false;
        }
        this.counts.set(key, seen + 1);

        const reqText = this.bodyText(ex.requestBody, ex.requestHeaders);
        const resText = this.bodyText(ex.responseBody, ex.responseHeaders);

        const entry = {
            startedDateTime: (ex.startedAt || new Date()).toISOString(),
            time: ex.timeMs === undefined ? 0 : ex.timeMs,
            request: {
                method: ex.method,
                url: ex.url.startsWith('http') ? ex.url : `http://localhost${ex.url}`,
                httpVersion: 'HTTP/1.1',
                cookies: [],
                headers: HarRecorder.headerList(ex.requestHeaders, true),
                // wiretap concatenates this with the query already present in
                // `url`, yielding values like 'space?include=space'. The URL is
                // authoritative, so leave the parsed copy empty.
                queryString: [],
                headersSize: -1,
                bodySize: ex.requestBody ? ex.requestBody.length : 0,
            },
            response: {
                status: ex.status,
                statusText: ex.statusText || '',
                httpVersion: 'HTTP/1.1',
                cookies: [],
                headers: HarRecorder.headerList(ex.responseHeaders, true),
                content: {
                    size: ex.responseBody ? ex.responseBody.length : 0,
                    mimeType: this.contentTypeOf(ex.responseHeaders) || 'application/json',
                    ...(resText === null ? {} : { text: resText }),
                },
                redirectURL: '',
                headersSize: -1,
                bodySize: ex.responseBody ? ex.responseBody.length : 0,
            },
            cache: {},
            timings: { send: 0, wait: ex.timeMs === undefined ? 0 : ex.timeMs, receive: 0 },
        };

        if (reqText !== null) {
            entry.request.postData = {
                mimeType: this.contentTypeOf(ex.requestHeaders) || 'application/json',
                text: reqText,
            };
        }

        this.entries.push(entry);
        return true;
    }

    get stats() {
        return { kept: this.entries.length, deduped: this.skipped, distinct: this.counts.size };
    }

    /** Write the HAR to disk. Safe to call more than once. */
    save() {
        const har = {
            log: {
                version: '1.2',
                creator: { name: 'capi-openapi-compliance', version: '1.0' },
                entries: this.entries,
            },
        };
        fs.mkdirSync(path.dirname(this.file), { recursive: true });
        fs.writeFileSync(this.file, JSON.stringify(har, null, 2));
        return this.file;
    }
}

module.exports = { HarRecorder };
