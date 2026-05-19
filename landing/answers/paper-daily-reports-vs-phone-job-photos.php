<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>Paper daily reports still exist. So does rain.</h1>
    <p class="lead">Signed paper has a ritual gravity phones struggle to copy. It also smears, gets left on truck dashboards, and turns into “I know I wrote it down somewhere.” Phones are worse at ceremony and better at backups—pick your poison honestly.</p>

    <h2>Keep paper for signatures</h2>
    <p>If the GC wants ink, give them ink. Photograph the signed page same day with a tag like <code>Sign-off</code> so the ritual and the searchable copy stay friends.</p>

    <h2>Let the phone carry the evidence</h2>
    <p>Photos beat adjectives for “how bad was the stain.” Voice beats handwriting when you are shivering. Export weekly if paranoia is healthy—it is.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Phone-native log without pretending paper never happened.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/examples/example-three-day-job-log-entries.php">Sample log entries</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Paper daily reports vs phone job photos',
    'description' => 'Paper sign-offs vs phone capture: when ink matters, when photos beat adjectives, and how to photograph signed pages.',
    'canonical_path' => '/answers/paper-daily-reports-vs-phone-job-photos.php',
    'body' => $body,
]);
