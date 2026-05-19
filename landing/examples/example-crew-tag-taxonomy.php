<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Tags a four-person crew can actually remember</h1>
    <p class="lead">If you have twelve tags, you have three tags in practice. Pick boring words and live with them.</p>

    <blockquote class="sample">
        <p><strong>Everyone uses:</strong> Before · During · After · Issue · Done · Hold</p>
        <p><strong>Lead only (optional):</strong> CO · RFI · Warranty</p>
        <p><strong>Room shortcuts (optional):</strong> KIT · BATH1 · BATH2 · MUD</p>
    </blockquote>

    <p>“Hold” means waiting on someone else’s decision. “Issue” means something is wrong with conditions or work. If those blur, your exports blur.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/guides/organize-job-site-photos-trades-and-tags.php">Organizing tags</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Example crew tag taxonomy',
    'description' => 'Sample tag set for a small crew: before/during/after, issue, hold, plus optional lead and room codes.',
    'canonical_path' => '/examples/example-crew-tag-taxonomy.php',
    'body' => $body,
]);
