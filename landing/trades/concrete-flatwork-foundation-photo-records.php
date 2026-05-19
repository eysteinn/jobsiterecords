<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Concrete: the pour you cannot “fix in post”</h1>
    <p class="lead">Rebar spacing, chair height, vapor barrier laps, anchor bolt templates—once the mud wins, you own whatever you forgot. Photos are cheap; chipping hammer is expensive.</p>

    <h2>Weather belongs in the record</h2>
    <p>Plastic sheeting blowing like a ghost? Hot wind drying the face too fast? Say it in a voice note with time. Nobody remembers Tuesday’s cloud cover in October arguments.</p>

    <h2>Control joints and edges</h2>
    <p>Before saw cut, after saw cut, curl on edges if you are fighting a picky architect. Boring beats poetic.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Wide shots + close-ups + captions = pour diary.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/trades/framing-rough-carpentry-documentation.php">Framing photos</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Concrete flatwork & foundation photo records',
    'description' => 'Concrete pour documentation: rebar, anchors, weather notes, control joints, edge curl—field photos before the mud wins.',
    'canonical_path' => '/trades/concrete-flatwork-foundation-photo-records.php',
    'body' => $body,
]);
