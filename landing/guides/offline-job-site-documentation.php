<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Offline job site documentation</h1>
    <p class="lead">Basements, steel buildings, and rural sites kill connectivity. Documentation still has to happen. The goal is a workflow that works with <strong>zero bars</strong>: capture now, organize by job, export when you have a moment.</p>

    <h2>Why offline-first matters</h2>
    <p>When an app depends on login or cloud upload before you can save a photo, the field breaks first. Contractors need a capture loop that finishes on device: shutter, short caption, tags like Before or Issue, optional voice note, save. That is what Job Site Records ships in Phase 1. No network calls, no account.</p>

    <h2>What you can document without signal</h2>
    <ul>
        <li><strong>Progress</strong>: dated photos that show scope as it moves.</li>
        <li><strong>Conditions</strong>: rot, buried pipes, out-of-level framing. Evidence for the client and the file.</li>
        <li><strong>Change conversations</strong>: a voice note beside the photo beats trying to remember tone three weeks later.</li>
    </ul>

    <h2>Sharing still works</h2>
    <p>Phase 1 does not sync to our servers. When you are ready to send proof, you export selected items as a <strong>zip archive</strong> and hand it to email, SMS, AirDrop, or Drive through your phone's normal share sheet. Building the zip can happen on site or later on Wi-Fi. Your choice.</p>

    <div class="guide-cta">
        <strong>Try Job Site Records</strong>
        <p>We are rolling out early access in waves. Request early access on the homepage and we will invite you when your spot opens.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="local-private-job-site-data.php">Local, private job site data</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
            <li><a href="daily-construction-job-log.php">Daily construction job log</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Offline job site documentation',
    'description' => 'Why offline-first documentation matters for contractors, what to capture without signal, and how zip export fits in. Job Site Records.',
    'canonical_path' => '/guides/offline-job-site-documentation.php',
    'body' => $body,
]);
