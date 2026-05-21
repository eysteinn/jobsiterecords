<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Job Site Records: free app vs Pro teams (roadmap)</h1>
    <p class="lead">We are explicit about phases so you know what exists today versus what requires a <strong>go decision</strong> after the MVP proves demand. This page summarizes the product promise from the public design direction. Not a contract, but the north star.</p>

    <h2>Phase 1. Free, local, account-less</h2>
    <ul>
        <li>Jobs with timelines; photos, voice notes, and text notes.</li>
        <li>Captions, tags, offline capture, device-only storage.</li>
        <li>Zip export with <code>index.html</code> and media folders.</li>
        <li>No PDF generator, no cloud sync, no in-app team sharing, no transcription.</li>
    </ul>

    <h2>Phase 2. Optional paid team subscription (if we ship it)</h2>
    <p>If metrics and waitlist interest justify the build, a later release may add encrypted cloud sync, a web dashboard, workspace billing (one subscription for the crew, not per phone), member invites with roles, branded PDF reports, and voice transcription to readable text. None of that is required to keep using the free local path.</p>

    <h2>Core commercial rule</h2>
    <p>Installing and using the app <strong>without</strong> turning on cloud features should remain free for full capture, organization, and zip export. Subscription is for teams that want shared access, sync, dashboard reporting, and server-backed generators. Not a tax on documenting a basement with no signal.</p>

    <div class="guide-cta">
        <strong>Tell us you want it</strong>
        <p>Early-access signups double-check demand for Phase 2. Request access from the homepage. And use Phase 1 in the field if you get early access.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="local-private-job-site-data.php">Local, private job site data</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
            <li><a href="voice-notes-for-contractors.php">Voice notes for contractors</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Free app vs Pro teams (roadmap)',
    'description' => 'Phase 1: free local capture and zip export. Phase 2 (if shipped): optional team sync, dashboard, PDFs, transcription. Job Site Records.',
    'canonical_path' => '/guides/job-site-records-free-vs-pro-teams.php',
    'body' => $body,
]);
