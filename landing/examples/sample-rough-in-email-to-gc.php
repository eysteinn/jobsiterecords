<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Rough-in email that does not apologize for existing</h1>
    <p class="lead">Attach your zip. Put the word ROUGH-IN in the subject. GCs live in search boxes.</p>

    <blockquote class="sample">
        <p><strong>Subject:</strong> Maple Ave — unit B — electrical rough-in photos (zip)</p>
        <p>Hey Avery,</p>
        <p>Rough trimmed and device boxes set per revised kitchen layout (v3 sheet). Zip has 18 images + index, clockwise from panel. Two notes in voice clips VX-01/02: microwave circuit per spec, island pendants shifted 6” per field dimension.</p>
        <p>Inspector window Wednesday AM as discussed. Call if you want anything re-shot before board.</p>
        <p>— Pat</p>
    </blockquote>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/trades/electrical-contractor-field-documentation.php">Electrical trade notes</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Sample rough-in email to GC',
    'description' => 'Example email to a GC for electrical rough-in with zip attachment, voice note refs, inspector window.',
    'canonical_path' => '/examples/sample-rough-in-email-to-gc.php',
    'body' => $body,
]);
