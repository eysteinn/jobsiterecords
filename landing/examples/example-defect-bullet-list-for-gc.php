<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Defect email bullets that do not sound like a lawsuit</h1>
    <p class="lead">Tight list, each line a photo you already took. Fictional garage slab.</p>

    <blockquote class="sample">
        <p>Avery — garage slab pour 5/6:</p>
        <ul>
            <li>East control joint wanders 3/4” off snap line ~mid-bay (see GC-JNT-02).</li>
            <li>Surface tear at south apron during bull float—photo GC-SUR-04, voice VX-01 explains repair plan.</li>
            <li>Anchor bolt template shifted 1/2” at NW corner; lather already notified, fix Friday (see GC-ANC-09).</li>
        </ul>
        <p>Zip attached with index. Not formal notice—just heads-up so walkthrough is not a surprise party.</p>
    </blockquote>

    <p class="muted">Not legal advice. Tone matches your relationship; some GCs want more formality.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/guides/construction-defect-documentation-checklist.php">Defect checklist</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Example defect bullet list for GC',
    'description' => 'Example bullet email for construction defects with photo IDs and short voice reference—informal heads-up style.',
    'canonical_path' => '/examples/example-defect-bullet-list-for-gc.php',
    'body' => $body,
]);
