<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Thirty seconds that do not wander</h1>
    <p class="lead">Read this out loud once, then throw it away and do your own version. The shape matters: room, fact, impact, ask.</p>

    <blockquote class="sample">
        <p>“Hall bath, north wall behind valve—drywall wet 12 inches up, soft to touch. Shut house angle stop, no drip now. Recommend opening 24 inches, fan dry, treat if mold. Need homeowner OK by tomorrow to stay on schedule for tile.”</p>
    </blockquote>

    <p>Thirty-four seconds if you talk slow. Still better than three vague minutes.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/answers/voice-notes-vs-typed-field-reports.php">Voice vs typed</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Example short field voice note script',
    'description' => 'Sample 30-second voice note script for a field issue: location, fact, mitigation, decision needed.',
    'canonical_path' => '/examples/example-short-field-voice-note-script.php',
    'body' => $body,
]);
