<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Change order photo set that tells a story</h1>
    <p class="lead">Fictional rotted sill, real structure. Names are fake. Order matters more than lens price.</p>

    <ol>
        <li><strong>IMG-101</strong> — Wide: north elevation, window at left, ladder for scale. Caption: “Sill rot under dining window, found during siding pull.”</li>
        <li><strong>IMG-102</strong> — Medium: framing below stool, insulation pulled back. Caption: “Damage extends 28” east of jack stud; sheathing sound above.”</li>
        <li><strong>IMG-103</strong> — Tight: rot pocket depth, tape in frame at 2-3/4”. Caption: “Max depth at center; stud faces mostly sound.”</li>
        <li><strong>VOX-04</strong> — 45s voice: what you recommend (sister vs replace), what GC said on phone, when you can have material on site.</li>
    </ol>

    <p>Export only these four into the CO bundle—nobody needs your lunch photo.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/guides/contractor-photo-evidence-for-change-orders.php">Change order evidence</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Example change order photo sequence',
    'description' => 'Example ordered photo set for a change order: wide, medium, tight, voice note—captions included.',
    'canonical_path' => '/examples/example-change-order-photo-sequence.php',
    'body' => $body,
]);
