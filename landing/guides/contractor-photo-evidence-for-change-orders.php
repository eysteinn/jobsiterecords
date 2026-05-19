<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/contractor-photo-evidence-for-change-orders.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'What photos help justify a change order?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Use wide shots for context, medium shots that show the affected assembly, and close-ups of the defect or hidden condition. Pair each set with a dated caption, tags like Issue or Completed, and a short voice note explaining scope impact and what you recommend next.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Why add voice notes next to change-order photos?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Voice preserves tone, sequence, and field nuance that captions alone lose, especially when you are one-handed on a ladder. Later transcription (where offered) can turn those clips into searchable text without replacing the original audio.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'How should contractors send change-order packages?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Export a curated zip of selected items with a readable index so the recipient can open photos and notes on any computer. Email remains common; use whatever channel your contract or GC expects, but keep one authoritative bundle per change event.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Contractor photo evidence for change orders</h1>
    <p class="lead">A change order sticks when the file reads like a story: <strong>what you found</strong>, <strong>why it was not in the original scope</strong>, and <strong>what it will take to fix it</strong>. Photos are the spine; captions, tags, and short voice notes are the narration.</p>

    <h2>Minimum viable evidence set</h2>
    <ol>
        <li><strong>Context</strong>: where on the site and which assembly.</li>
        <li><strong>Condition</strong>: rot, buried lines, out-of-spec work, failed flashing.</li>
        <li><strong>Measurement</strong>: when numbers matter, show the tape or level in frame.</li>
        <li><strong>Recommended correction</strong>: even a rough description helps align price and scope.</li>
    </ol>

    <h2>Tags that keep bundles readable months later</h2>
    <p>Consistent labels beat clever ones. Examples: Before, During, After, Issue, Completed, RFI. Pick a small set and reuse them so exports sort into a coherent timeline for owners and PMs.</p>

    <section aria-labelledby="faq-co">
        <h2 id="faq-co">Quick answers</h2>
        <h3>What photos help justify a change order?</h3>
        <p>Use wide shots for context, medium shots that show the affected assembly, and close-ups of the defect or hidden condition. Pair each set with a dated caption, tags like Issue or Completed, and a short voice note explaining scope impact and what you recommend next.</p>
        <h3>Why add voice notes next to change-order photos?</h3>
        <p>Voice preserves tone, sequence, and field nuance that captions alone lose, especially when you are one-handed on a ladder. Later transcription (where offered) can turn those clips into searchable text without replacing the original audio.</p>
        <h3>How should contractors send change-order packages?</h3>
        <p>Export a curated zip of selected items with a readable index so the recipient can open photos and notes on any computer. Email remains common; use whatever channel your contract or GC expects, but keep one authoritative bundle per change event.</p>
    </section>

    <div class="guide-cta">
        <strong>Document scope shifts on the phone</strong>
        <p>Job Site Records is built for capture now and export when you are ready.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="document-issues-and-change-orders.php">Document issues and change orders</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
            <li><a href="voice-notes-for-contractors.php">Voice notes for contractors</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Photo evidence for change orders',
    'description' => 'How contractors should photograph, tag, caption, and export change-order evidence so owners and GCs can follow the story.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
