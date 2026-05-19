<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/client-progress-updates-without-pm-software.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'How can contractors send client progress updates without PM software?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Maintain a dated timeline of photos, captions, and short voice notes per job, then export a curated zip or share a consistent weekly bundle through email or messaging. The goal is predictable format and timing, not a heavyweight portal.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'What should every homeowner update include?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Three to eight images showing visible progress, one or two issue frames if something changed, a one-line summary of work completed since the last update, and any decisions waiting on the client.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'How often should remodel crews send updates?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Weekly is a practical default for active phases; quiet weeks can be skipped. Spike frequency during rough-in or finish when visual change accelerates or when approvals are pending.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Client progress updates without PM software</h1>
    <p class="lead">Owners rarely want another login. They want <strong>clear photos on a steady cadence</strong> and plain language about what happened this week. A lightweight capture habit plus a repeatable export beats half-configured construction portals.</p>

    <h2>Template owners understand</h2>
    <ul>
        <li><strong>This week</strong>: tasks completed with dated photos.</li>
        <li><strong>Decisions needed</strong>: fixtures, paint line, change impacts.</li>
        <li><strong>Next week</strong>: planned work and access needs.</li>
    </ul>

    <h2>Why zip bundles still work</h2>
    <p>A single archive with an index file opens on any laptop for partners, designers, or lenders who do not live in your chat app. Keep filenames boring and descriptive so recipients trust the attachment.</p>

    <section aria-labelledby="faq-client">
        <h2 id="faq-client">Quick answers</h2>
        <h3>How can contractors send client progress updates without PM software?</h3>
        <p>Maintain a dated timeline of photos, captions, and short voice notes per job, then export a curated zip or share a consistent weekly bundle through email or messaging. The goal is predictable format and timing, not a heavyweight portal.</p>
        <h3>What should every homeowner update include?</h3>
        <p>Three to eight images showing visible progress, one or two issue frames if something changed, a one-line summary of work completed since the last update, and any decisions waiting on the client.</p>
        <h3>How often should remodel crews send updates?</h3>
        <p>Weekly is a practical default for active phases; quiet weeks can be skipped. Spike frequency during rough-in or finish when visual change accelerates or when approvals are pending.</p>
    </section>

    <div class="guide-cta">
        <strong>Per-job timelines, not scattered threads</strong>
        <p>Job Site Records keeps homeowner-ready evidence organized for export.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="before-during-after-construction-photos.php">Before, during, and after photos</a></li>
            <li><a href="daily-construction-job-log.php">Daily construction job log</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Client updates without PM software',
    'description' => 'How contractors can send steady homeowner progress updates with photos and zip exports. No construction portal required.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
