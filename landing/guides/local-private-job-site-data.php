<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Local, private job site data</h1>
    <p class="lead">"We take privacy seriously" is easy to say. Harder is a product architecture where, in Phase 1, <strong>your job content never touches our servers</strong> because there is no sync and no analytics SDK. Capture, browse, and export stay on the phone.</p>

    <h2>What stays on device</h2>
    <p>Jobs, timeline items, photos, audio, captions, tags, and text notes live in the app sandbox (SQLite plus media files on disk). Sharing happens only when <strong>you</strong> invoke the OS share sheet on an export you generated.</p>

    <h2>What we still learn (without spying)</h2>
    <p>Store-provided metrics like installs, retention, and ratings help us improve the product without breaking the privacy story. Optional email waitlists and feedback mailto links are explicit opt-in. That trade keeps the trust line clean while we validate demand.</p>

    <h2>Future optional cloud (Phase 2)</h2>
    <p>A later paid team subscription may add encrypted sync, a browser dashboard, and shared workspaces. Marketing language will evolve to "does not leave your device <em>unless you turn on sync</em>" for users who opt in. Local-only use remains free so the field workflow is never held hostage.</p>

    <div class="guide-cta">
        <strong>Work without the cloud</strong>
        <p>Request early access to Job Site Records from the homepage.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="offline-job-site-documentation.php">Offline job site documentation</a></li>
            <li><a href="job-site-records-free-vs-pro-teams.php">Free app vs Pro teams (roadmap)</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Local, private job site data',
    'description' => 'Phase 1 keeps photos and voice on your device with no cloud or analytics SDK. How exports and future optional sync fit in.',
    'canonical_path' => '/guides/local-private-job-site-data.php',
    'body' => $body,
]);
