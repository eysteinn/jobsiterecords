<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/organize-job-site-photos-trades-and-tags.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'How should contractors organize job site photos?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Use one folder or job per project, a chronological timeline inside that job, and a small, repeated set of tags (for example Before, Issue, Completed) plus short captions. Consistency matters more than elaborate folder trees.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Should tags be trade-specific?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Add a few trade tags if they help your crew speak plainly. Rough-in, Tile ready, Panel label. But keep the core set universal so PMs and owners can scan exports without learning your internal jargon.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'What makes a good photo caption on a job site?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Answer location, what changed, and why it matters in one line when possible. Example: "Hall bath: old valve corroded; replacing with 1/2 PEX drop; shutoff at hall closet." Future-you should understand it without audio.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Organize job site photos with trades and tags</h1>
    <p class="lead">Disorganized photos are <strong>silent liabilities</strong>. The fix is not more albums. It is a <strong>repeatable vocabulary</strong>: one job container, a timeline, tags your whole crew will reuse, and captions that read well six months later.</p>

    <h2>Start with a tiny tag palette</h2>
    <p>Pick five to eight tags and refuse the rest on the critical path. Examples that work across trades: Before, During, After, Issue, RFI, Completed, Hold. Add one or two company-specific labels only if everyone agrees what they mean.</p>

    <h2>Layer trade context without clutter</h2>
    <p>Electricians might tag Panel, Rough-in, Trim-out; plumbers might use DWV, Supply, Fixture test. Keep those as secondary tags so owners still see a coherent story in a generic export.</p>

    <section aria-labelledby="faq-org">
        <h2 id="faq-org">Quick answers</h2>
        <h3>How should contractors organize job site photos?</h3>
        <p>Use one folder or job per project, a chronological timeline inside that job, and a small, repeated set of tags (for example Before, Issue, Completed) plus short captions. Consistency matters more than elaborate folder trees.</p>
        <h3>Should tags be trade-specific?</h3>
        <p>Add a few trade tags if they help your crew speak plainly. Rough-in, Tile ready, Panel label. But keep the core set universal so PMs and owners can scan exports without learning your internal jargon.</p>
        <h3>What makes a good photo caption on a job site?</h3>
        <p>Answer location, what changed, and why it matters in one line when possible. Example: "Hall bath: old valve corroded; replacing with 1/2 PEX drop; shutoff at hall closet." Future-you should understand it without audio.</p>
    </section>

    <div class="guide-cta">
        <strong>Tags + captions beside every capture</strong>
        <p>Job Site Records is designed so tagging does not feel like paperwork.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="tag-and-caption-site-photos.php">Tag and caption site photos</a></li>
            <li><a href="field-documentation-trades-remodel.php">Field documentation for trades</a></li>
            <li><a href="before-during-after-construction-photos.php">Before, during, and after photos</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Organize job site photos with tags',
    'description' => 'Practical tagging and caption rules so contractor photo sets stay readable for GCs, owners, and future-you.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
