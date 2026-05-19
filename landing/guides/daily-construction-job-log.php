<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Daily construction job log</h1>
    <p class="lead">A daily log does not have to be a clipboard novel. For small crews, the best habit is <strong>one chronological timeline per job</strong>: what happened, in order, with proof attached. That is easier to review than fifty unrelated camera-roll shots.</p>

    <h2>What belongs in the log</h2>
    <ul>
        <li>Arrivals and major tasks completed.</li>
        <li>Materials delivered or delayed.</li>
        <li>Inspections, tests, or failures.</li>
        <li>Conversations that changed scope. Voice plus a caption helps.</li>
    </ul>

    <h2>How Job Site Records models it</h2>
    <p>Each <strong>Job</strong> has a timeline grouped by date. Items can be photos, standalone voice notes, or text notes. Tags classify entries without breaking chronology. Search and filters on the job list help you jump back to active work.</p>

    <h2>Export when someone asks "what happened Tuesday?"</h2>
    <p>Select the relevant date range (export supports ordering and optional date filters), include captions and tags, and share the zip. The embedded <code>index.html</code> gives a readable single-page summary for people who will never install an app.</p>

    <div class="guide-cta">
        <strong>Keep one timeline per job</strong>
        <p>Get on the early-access list for Job Site Records on the homepage.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="offline-job-site-documentation.php">Offline job site documentation</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
            <li><a href="field-documentation-trades-remodel.php">Field documentation for trades</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Daily construction job log',
    'description' => 'Build a simple daily job log: timeline per job, photos and voice, zip export. Job Site Records for small crews.',
    'canonical_path' => '/guides/daily-construction-job-log.php',
    'body' => $body,
]);
