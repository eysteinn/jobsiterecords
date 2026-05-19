<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/voice-memos-vs-notes-field-documentation.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'When should contractors use voice memos instead of typed notes?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Use voice when hands are dirty, when you are moving, when sequence matters, or when explaining nuance faster than typing. Use short typed notes for labels, lists, or exact model numbers you might mis-speak.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Do voice memos replace photos?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'No. Voice complements photos: the picture shows the fact; the memo explains implication, next steps, and who said what. Together they survive memory loss on busy weeks.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'How long should a field voice note be?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Aim for thirty seconds to three minutes. State job area, what you observed, and recommended action. If you need longer, split into two clips tied to different photos so exports stay scannable.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Voice memos vs notes for field documentation</h1>
    <p class="lead">Neither wins alone. <strong>Voice</strong> wins on speed and nuance when you cannot stop to type. <strong>Short text</strong> wins for serial numbers, SKU stickers, and anything you will copy-paste later. The best workflow alternates both and keeps them beside the same photo.</p>

    <h2>Pairing pattern that holds up in disputes</h2>
    <ol>
        <li>Photo of the condition.</li>
        <li>Caption with location + object.</li>
        <li>Voice memo with impact, options, and who you notified.</li>
    </ol>

    <h2>Accessibility and search</h2>
    <p>Audio is fast to create but slower for some readers to consume. When transcription is available as a product feature, treat it as an index layer, and keep the original clip for tone and detail.</p>

    <section aria-labelledby="faq-voice">
        <h2 id="faq-voice">Quick answers</h2>
        <h3>When should contractors use voice memos instead of typed notes?</h3>
        <p>Use voice when hands are dirty, when you are moving, when sequence matters, or when explaining nuance faster than typing. Use short typed notes for labels, lists, or exact model numbers you might mis-speak.</p>
        <h3>Do voice memos replace photos?</h3>
        <p>No. Voice complements photos: the picture shows the fact; the memo explains implication, next steps, and who said what. Together they survive memory loss on busy weeks.</p>
        <h3>How long should a field voice note be?</h3>
        <p>Aim for thirty seconds to three minutes. State job area, what you observed, and recommended action. If you need longer, split into two clips tied to different photos so exports stay scannable.</p>
    </section>

    <div class="guide-cta">
        <strong>Voice next to every timeline item</strong>
        <p>Job Site Records treats voice as a first-class field capture, not an afterthought.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="voice-notes-for-contractors.php">Voice notes for contractors</a></li>
            <li><a href="document-issues-and-change-orders.php">Document issues and change orders</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Voice memos vs notes in the field',
    'description' => 'When contractors should record voice vs type notes, how to pair audio with photos, and ideal clip length for job documentation.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
