<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/subcontractor-to-gc-documentation-handoff.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'What should subcontractors send the GC at rough-in?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Tagged photos of concealed work before cover, like hangers, penetrations, pipe slopes where visible, wire routing, and test results when photographed, plus short voice or text notes calling out anything atypical. Bundle by area and date.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'How do you make a subcontractor photo package easy to review?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Use consistent tags, chronological order, and filenames or an included index that maps images to levels and rooms. Avoid dumping hundreds of unlabeled frames.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Is email still acceptable for GC handoffs?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => "Yes, when attachments are organized and size limits respected. Split into dated zips if needed, or follow the GC's preferred upload link. But always keep a copy in your own job record.",
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Subcontractor to GC documentation handoff</h1>
    <p class="lead">GCs do not lack photos. They lack <strong>labeled, dated proof of concealed work</strong> they can forward to inspectors, owners, or future trades. Your handoff wins when it reads like a punch list in reverse: complete, ordered, and scoped by location.</p>

    <h2>Minimum rough-in package</h2>
    <ul>
        <li>Before coverage shots for every bay you touched.</li>
        <li>Close-ups of anchors, hangers, straps, and labels that code cares about.</li>
        <li>Notes on anything that deviates from plan and why.</li>
    </ul>

    <h2>Finish phase extras</h2>
    <p>Trim photos with model numbers visible, startup checks, and any owner selections confirmed in frame reduce callbacks and warranty noise.</p>

    <section aria-labelledby="faq-gc">
        <h2 id="faq-gc">Quick answers</h2>
        <h3>What should subcontractors send the GC at rough-in?</h3>
        <p>Tagged photos of concealed work before cover, like hangers, penetrations, pipe slopes where visible, wire routing, and test results when photographed, plus short voice or text notes calling out anything atypical. Bundle by area and date.</p>
        <h3>How do you make a subcontractor photo package easy to review?</h3>
        <p>Use consistent tags, chronological order, and filenames or an included index that maps images to levels and rooms. Avoid dumping hundreds of unlabeled frames.</p>
        <h3>Is email still acceptable for GC handoffs?</h3>
        <p>Yes, when attachments are organized and size limits respected. Split into dated zips if needed, or follow the GC's preferred upload link. But always keep a copy in your own job record.</p>
    </section>

    <div class="guide-cta">
        <strong>Export clean bundles from the field</strong>
        <p>Job Site Records helps crews keep per-job evidence ready for GC review.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="field-documentation-trades-remodel.php">Field documentation for trades</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
            <li><a href="contractor-photo-evidence-for-change-orders.php">Photo evidence for change orders</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Subcontractor documentation for GCs',
    'description' => 'What to include in rough-in and finish photo packages for general contractors. Tags, sequencing, and practical delivery.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
