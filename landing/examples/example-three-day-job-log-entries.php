<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Three days of “good enough” log text</h1>
    <p class="lead">Not poetry. Enough that Tuesday-you knows what Wednesday-you did.</p>

    <blockquote class="sample">
        <p><strong>Tue 4/9</strong> — Crew: me + Jay. Set forms east drive, rebar chairs fixed at dogleg. Rain stopped at 2; pour still on for Thu AM.</p>
        <p><strong>Wed 4/10</strong> — Stripped forms south walk only; north still green. Inspector called out edge honeycomb at step—photo set STEP-01–03, patch scheduled Fri.</p>
        <p><strong>Thu 4/11</strong> — Pour 7:30. Air 62°F, sheet per batch cards in truck file. Cylinder samples tagged A/B as usual.</p>
    </blockquote>

    <p>Pair each day with a few photos in the same job timeline and you are suddenly the organized one.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/guides/daily-construction-job-log.php">Daily log guide</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Example three-day job log entries',
    'description' => 'Sample short daily log entries for concrete/formwork: crew, weather, inspector notes, pour day basics.',
    'canonical_path' => '/examples/example-three-day-job-log-entries.php',
    'body' => $body,
]);
