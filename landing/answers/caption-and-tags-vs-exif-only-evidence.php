<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>EXIF knows time. It does not know intent.</h1>
    <p class="lead">Every photo already carries timestamps—great for ordering, useless for explaining why you moved a condensate pump. Tags and captions are the human layer that survives forwarding, printing, and that one guy who still uses Outlook 2013.</p>

    <h2>Lean on EXIF for</h2>
    <p>Sequence checks, rough “when was this,” sanity that nobody reordered files badly.</p>

    <h2>Lean on captions/tags for</h2>
    <p>Room names, trade context, issue vs done, anything you would say out loud to a tired superintendent.</p>

    <p>If your evidence strategy is “sort by date and hope,” you will eventually lose a fight to someone who wrote six words on the photo.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Tags + captions live beside media on the timeline—not buried in metadata dialogs.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/guides/photo-captions-metadata-construction-documentation.php">Captions &amp; metadata guide</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Captions & tags vs EXIF-only evidence',
    'description' => 'Why EXIF timestamps are not enough for construction evidence and how captions and tags carry intent.',
    'canonical_path' => '/answers/caption-and-tags-vs-exif-only-evidence.php',
    'body' => $body,
]);
