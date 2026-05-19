<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Field documentation for trades (remodel to landscaping)</h1>
    <p class="lead">The same documentation problem shows up across trades: <strong>prove what you found, what you installed, and what you left behind</strong>. Electricians, plumbers, framers, painters, landscapers, and remodelers all benefit from dated photos, voice for nuance, and exports the office can open.</p>

    <h2>One app pattern, many trades</h2>
    <p>Job Site Records does not hard-code a single vertical. You name jobs (client, address, job number), capture to a timeline, and tag in language that matches your work. A waterproofing crew might lean on Issue and After; a painter might lean on Completed; a landscaper might add custom tags for zones or plant batches.</p>

    <h2>Small crew reality</h2>
    <p>Enterprise construction software is overkill when you are six people and three active jobs. What you need is reliable capture offline, quick review in the truck, and a zip when someone asks for pictures. That is the Phase 1 focus. Fast field notes, not a full PM suite.</p>

    <h2>When teams outgrow one phone</h2>
    <p>If multiple people need the same living job file, a future optional subscription tier is planned: workspace billing, invites, roles, sync, and a web dashboard. Until then, many crews still win by designating one device as the recorder or by exporting daily for the office.</p>

    <div class="guide-cta">
        <strong>Built for the trades</strong>
        <p>Request early access to Job Site Records on the homepage.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="daily-construction-job-log.php">Daily construction job log</a></li>
            <li><a href="offline-job-site-documentation.php">Offline job site documentation</a></li>
            <li><a href="job-site-records-free-vs-pro-teams.php">Free app vs Pro teams (roadmap)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Field documentation for trades',
    'description' => 'Document remodel, plumbing, electrical, landscaping, and more with one offline-first workflow. Job Site Records for small crews.',
    'canonical_path' => '/guides/field-documentation-trades-remodel.php',
    'body' => $body,
]);
