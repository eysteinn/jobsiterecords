<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Document issues and change orders</h1>
    <p class="lead">Most margin loss is not bad luck. It is <strong>unwritten scope</strong>. When a wall opens up to rot, or a spec was ambiguous, you need a dated, shareable record: what you saw, when you saw it, and what you recommended. Photos plus a short voice note beat a long text thread.</p>

    <h2>Use the Issue tag on purpose</h2>
    <p>Reserving <strong>Issue</strong> for real surprises keeps filters honest. Pair the tag with a caption that states facts ("subfloor saturated 24 inches out from tub") and add voice if you need to walk someone through options. Later, your timeline sorts by date so the story reads in order.</p>

    <h2>Change-order justification</h2>
    <p>Change orders live or die on clarity. A zip export that contains captioned photos, tagged items, timestamps, and optional text notes gives the office or homeowner something they can forward without special software. Phase 1 delivers <code>index.html</code> and <code>index.csv</code> inside the archive; formal branded PDFs are planned for the optional web dashboard tier later. Not a blocker for evidence today.</p>

    <h2>Privacy stays intact until you share</h2>
    <p>Nothing uploads automatically. You choose when to export and which app receives the zip from the OS share sheet. That keeps sensitive job photos off random cloud folders until you are ready.</p>

    <div class="guide-cta">
        <strong>Document with confidence</strong>
        <p>Request early access to Job Site Records on the homepage.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="before-during-after-construction-photos.php">Before, during, and after construction photos</a></li>
            <li><a href="tag-and-caption-site-photos.php">Tag and caption site photos</a></li>
            <li><a href="local-private-job-site-data.php">Local, private job site data</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Document issues and change orders',
    'description' => 'Tag issues, pair photos with voice, and export proof for change orders. Local-first workflow with Job Site Records.',
    'canonical_path' => '/guides/document-issues-and-change-orders.php',
    'body' => $body,
]);
