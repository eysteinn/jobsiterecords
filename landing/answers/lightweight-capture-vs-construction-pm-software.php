<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>PM software vs a camera that behaves</h1>
    <p class="lead">Construction PM suites are Swiss army warehouses: scheduling, submittals, RFIs, the sacred ritual of duplicate data entry. Sometimes you just need to prove you installed the right valve before insulation. That is not a Gantt problem.</p>

    <h2>Use the PM tool for PM work</h2>
    <p>When contracts, bonds, and compliance live there—live there. Nobody is telling you to replace Procore with vibes.</p>

    <h2>Use lightweight capture for capture work</h2>
    <p>Photos, tags, voice, export. If your PM suite already swallows photos happily, great—export and upload. If it does not, you still need a place that does not require a training webinar to snap a stud pack.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Narrow scope: job → capture → zip. Not a PM replacement.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/use-cases/commercial-ti-field-documentation.php">TI field documentation</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Lightweight capture vs construction PM software',
    'description' => 'When full PM suites make sense vs when lightweight photo and note capture is the right layer for field crews.',
    'canonical_path' => '/answers/lightweight-capture-vs-construction-pm-software.php',
    'body' => $body,
]);
