<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/photo-captions-metadata-construction-documentation.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'What is photo metadata in construction documentation?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Metadata is data about the photo: capture time, device, and sometimes GPS. Captions and tags you add are human metadata. They explain meaning a timestamp cannot, like which room or which phase.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Why are captions more reliable than EXIF alone?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'EXIF shows when a file was saved, not what trade decision it supports. A caption ties the image to scope, location, and next steps so exports make sense outside your phone.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Should contractors geotag every job photo?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Only when it helps and privacy allows. For many residential jobs, a caption naming the address or room is enough. Geotags can be sensitive; prefer deliberate captions for handoff packages.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Photo captions and metadata for construction docs</h1>
    <p class="lead">Automatic metadata (time, device) is <strong>thin context</strong>. The metadata that wins disputes and delights clients is <strong>what you write</strong>: short captions, disciplined tags, and voice when nuance matters.</p>

    <h2>Caption formula that scales</h2>
    <p><strong>Where + what + so what.</strong> Example: "Kitchen north wall. Removed failed backerboard; moisture reading 18% at stud; drying 48h before cement board." That line beats a thousand silent tiles photos.</p>

    <h2>Tags vs captions</h2>
    <p>Tags are filters: Before, Issue, Completed. Captions are sentences. Use tags for sorting exports; use captions to explain judgment calls and sequence.</p>

    <section aria-labelledby="faq-meta">
        <h2 id="faq-meta">Quick answers</h2>
        <h3>What is photo metadata in construction documentation?</h3>
        <p>Metadata is data about the photo: capture time, device, and sometimes GPS. Captions and tags you add are human metadata. They explain meaning a timestamp cannot, like which room or which phase.</p>
        <h3>Why are captions more reliable than EXIF alone?</h3>
        <p>EXIF shows when a file was saved, not what trade decision it supports. A caption ties the image to scope, location, and next steps so exports make sense outside your phone.</p>
        <h3>Should contractors geotag every job photo?</h3>
        <p>Only when it helps and privacy allows. For many residential jobs, a caption naming the address or room is enough. Geotags can be sensitive; prefer deliberate captions for handoff packages.</p>
    </section>

    <div class="guide-cta">
        <strong>Captions beside every capture</strong>
        <p>Job Site Records nudges crews toward readable timelines, not silent rolls.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="tag-and-caption-site-photos.php">Tag and caption site photos</a></li>
            <li><a href="organize-job-site-photos-trades-and-tags.php">Organize job site photos with tags</a></li>
            <li><a href="before-during-after-construction-photos.php">Before, during, and after photos</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Captions and metadata for construction photos',
    'description' => 'How captions, tags, and EXIF differ for job-site documentation, plus the caption formula contractors can reuse.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
