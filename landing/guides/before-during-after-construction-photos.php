<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Before, during, and after construction photos</h1>
    <p class="lead">Clients do not remember every rough-in they signed off. A clear <strong>before / during / after</strong> set reduces disputes, speeds approvals, and shows craftsmanship. The trick is making it habitual. Not a separate project at the end of the week.</p>

    <h2>Default tags that match how jobs run</h2>
    <p>Job Site Records ships with tags including <strong>Before</strong>, <strong>During</strong>, <strong>After</strong>, <strong>Issue</strong>, and <strong>Completed</strong>, and you can add trade-specific labels (for example Electrical or Cabinets). Tagging at capture time takes seconds and pays off when you export or skim the timeline months later.</p>

    <h2>Practical tips on site</h2>
    <ul>
        <li>Shoot wide first, then detail. Context plus the specific defect or finish.</li>
        <li>One room or system per "chapter" keeps the timeline readable.</li>
        <li>Use <strong>Issue</strong> the moment something unexpected appears; pair it with a short voice note while memory is fresh.</li>
    </ul>

    <h2>Handoff without heavy software</h2>
    <p>In Phase 1 the app exports a zip with photos, voice notes, text notes, a browser-openable <code>index.html</code>, a spreadsheet-friendly <code>index.csv</code>, and structured <code>job.json</code>. Branded PDF reports are planned for a later optional team tier with a web dashboard. Not required to deliver solid evidence today.</p>

    <div class="guide-cta">
        <strong>Build the habit on your phone</strong>
        <p>Request early access to Job Site Records and get invited when your wave opens.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="tag-and-caption-site-photos.php">Tag and caption site photos</a></li>
            <li><a href="document-issues-and-change-orders.php">Document issues and change orders</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Before, during, and after construction photos',
    'description' => 'Use before/during/after photos and tags to protect your work and keep clients aligned. How Job Site Records supports the habit.',
    'canonical_path' => '/guides/before-during-after-construction-photos.php',
    'body' => $body,
]);
