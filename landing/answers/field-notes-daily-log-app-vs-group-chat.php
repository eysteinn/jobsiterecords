<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>Group chat is not a filing cabinet</h1>
    <p class="lead">Slack, Teams, iMessage—they are incredible for “where are you?” They are miserable for “show me the rough-in on unit 4 from March.” Search gets weird, media compresses, and jokes bury the one photo the inspector needed.</p>

    <h2>Chat wants to be ephemeral</h2>
    <p>That is a feature for birthday plans. It is a bug for warranty photos.</p>

    <h2>A per-job log is boring on purpose</h2>
    <p>Timeline, tags, export. You can still paste links in chat—just stop letting chat be the database of record unless you enjoy pain.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Job-scoped timelines instead of scroll archaeology.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/guides/offline-construction-daily-log-app.php">Offline daily log (guide)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Daily log app vs group chat',
    'description' => 'Why group chat fails as construction documentation and what a per-job timeline fixes without killing your memes channel.',
    'canonical_path' => '/answers/field-notes-daily-log-app-vs-group-chat.php',
    'body' => $body,
]);
