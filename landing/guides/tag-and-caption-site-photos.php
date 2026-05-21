<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Tag and caption site photos</h1>
    <p class="lead">A thousand unnamed <code>IMG_4821.jpg</code> files help nobody. Captions and tags turn a dump of pixels into a <strong>story someone else can follow</strong>: your future self, the office, or the homeowner.</p>

    <h2>Tags for state, captions for facts</h2>
    <p>Use tags for coarse state: Before, During, After, Issue, Completed, or labels you define for your trade. Use captions for specifics: measurements, model numbers, who was on site, what was agreed. The combination survives export in <code>index.html</code>.</p>

    <h2>Defaults you can extend</h2>
    <p>The app ships a sensible starter set and lets you manage your tag library in settings. Add, rename, delete, reorder. Recent tags surface during capture so the habit stays fast.</p>

    <h2>Speed on the job</h2>
    <p>The capture flow is built for gloves and sunlight: photo, retake or save, caption field, chips for tags, optional voice note, done. Fast capture beats perfect prose; you can edit later from item detail if needed.</p>

    <div class="guide-cta">
        <strong>Make every photo legible</strong>
        <p>Request early access on the homepage.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="before-during-after-construction-photos.php">Before, during, and after construction photos</a></li>
            <li><a href="document-issues-and-change-orders.php">Document issues and change orders</a></li>
            <li><a href="daily-construction-job-log.php">Daily construction job log</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Tag and caption site photos',
    'description' => 'Use tags and captions so job site photos stay organized through export. Defaults, custom tags, and fast capture with Job Site Records.',
    'canonical_path' => '/guides/tag-and-caption-site-photos.php',
    'body' => $body,
]);
