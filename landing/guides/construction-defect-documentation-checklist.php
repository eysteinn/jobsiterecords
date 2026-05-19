<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/construction-defect-documentation-checklist.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'What should a construction defect photo checklist include?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Wide context, medium framing on the assembly, close-up of the defect, any label or stamp visible, measurement or level in frame when relevant, and a caption stating location, observed condition, and immediate safety actions if any.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Should contractors photograph people in defect documentation?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Avoid identifiable faces unless necessary and permitted. Focus on conditions, equipment settings, gauges, and installed work. Note witness names in text if required by process.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Is this checklist legal advice?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'No. It is a practical field documentation pattern. Follow your contract, insurer, and counsel for formal notice requirements.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Construction defect documentation checklist</h1>
    <p class="lead">Defect documentation exists so <strong>facts survive arguments</strong>. Use a repeatable shot list every time. Stress drops when you know you already captured the room, the assembly, and the failure mode.</p>

    <h2>Field checklist (copy mentally)</h2>
    <ol>
        <li><strong>Establish location</strong>: wide shot with permanent reference (door tag, window, column line).</li>
        <li><strong>Show assembly</strong>: how the defect relates to surrounding work.</li>
        <li><strong>Zoom the failure</strong>: crack pattern, corrosion, misalignment, water track.</li>
        <li><strong>Capture measurements</strong>: gap sizes, moisture readings, level bubble.</li>
        <li><strong>Record sequence</strong>: short voice note: when noticed, who was notified, interim mitigation.</li>
        <li><strong>Tag consistently</strong>: Issue, Hold, RFI as your team defines them.</li>
    </ol>

    <p class="muted">This article is practical guidance, not legal advice. Use your contract and counsel for formal notice steps.</p>

    <section aria-labelledby="faq-defect">
        <h2 id="faq-defect">Quick answers</h2>
        <h3>What should a construction defect photo checklist include?</h3>
        <p>Wide context, medium framing on the assembly, close-up of the defect, any label or stamp visible, measurement or level in frame when relevant, and a caption stating location, observed condition, and immediate safety actions if any.</p>
        <h3>Should contractors photograph people in defect documentation?</h3>
        <p>Avoid identifiable faces unless necessary and permitted. Focus on conditions, equipment settings, gauges, and installed work. Note witness names in text if required by process.</p>
        <h3>Is this checklist legal advice?</h3>
        <p>No. It is a practical field documentation pattern. Follow your contract, insurer, and counsel for formal notice requirements.</p>
    </section>

    <div class="guide-cta">
        <strong>Tag issues beside the timeline</strong>
        <p>Job Site Records keeps defect evidence with captions and voice in one job record.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="document-issues-and-change-orders.php">Document issues and change orders</a></li>
            <li><a href="contractor-photo-evidence-for-change-orders.php">Photo evidence for change orders</a></li>
            <li><a href="before-during-after-construction-photos.php">Before, during, and after photos</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Defect documentation checklist',
    'description' => 'A contractor checklist for photographing construction defects: context, close-ups, measurements, tags, and voice sequence.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
