<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/offline-construction-daily-log-app.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'What is an offline construction daily log?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'An offline daily log is a chronological record of job-site work. Photos, short notes, and voice memos. Saved entirely on device without requiring login, upload, or connectivity at capture time.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Why not use group chat as the daily log?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Chat threads bury context, mix jobs, and age poorly in search. A per-job timeline keeps evidence together, dated, and exportable as a single archive for disputes, warranties, or client updates.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'What should crews log each day?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Weather or site constraints if relevant, crew on site, major tasks completed, materials received, safety or access issues, and photos of progress or problems. Brevity wins; the timeline fills naturally if capture is easy.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Offline construction daily log app</h1>
    <p class="lead">The best daily log is the one you keep. If it needs signal, passwords, or "upload pending," it fails in basements and steel buildings. An <strong>offline-first app</strong> lets you log in the moment and sync or export later. On your terms.</p>

    <h2>What belongs in a daily log</h2>
    <p>Think defensibility, not diary length. A few dated photos with captions, quick voice notes while gloves are on, and tags for progress versus issues beat a paragraph nobody will read.</p>

    <h2>How this differs from generic camera rolls</h2>
    <p>Camera rolls mix kids' soccer with a leaking shutoff valve. A job-scoped timeline keeps exports clean: select the last two weeks, zip, send. Without exposing unrelated personal media.</p>

    <section aria-labelledby="faq-log">
        <h2 id="faq-log">Quick answers</h2>
        <h3>What is an offline construction daily log?</h3>
        <p>An offline daily log is a chronological record of job-site work. Photos, short notes, and voice memos. Saved entirely on device without requiring login, upload, or connectivity at capture time.</p>
        <h3>Why not use group chat as the daily log?</h3>
        <p>Chat threads bury context, mix jobs, and age poorly in search. A per-job timeline keeps evidence together, dated, and exportable as a single archive for disputes, warranties, or client updates.</p>
        <h3>What should crews log each day?</h3>
        <p>Weather or site constraints if relevant, crew on site, major tasks completed, materials received, safety or access issues, and photos of progress or problems. Brevity wins; the timeline fills naturally if capture is easy.</p>
    </section>

    <div class="guide-cta">
        <strong>Built for zero bars</strong>
        <p>Job Site Records targets offline capture with zip export when you are ready to share.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="daily-construction-job-log.php">Daily construction job log</a></li>
            <li><a href="offline-job-site-documentation.php">Offline job site documentation</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Offline construction daily log app',
    'description' => 'Why offline daily logs beat chat threads, what to record each day, and how per-job timelines simplify exports for contractors.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
