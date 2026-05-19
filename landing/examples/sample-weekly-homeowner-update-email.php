<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Weekly update email that does not waste a Friday</h1>
    <p class="lead">Keep the subject boring so people can find it later. Attach or link your bundle—here we pretend you zipped five photos and dropped them in Drive like a civilized person.</p>

    <blockquote class="sample">
        <p><strong>Subject:</strong> 1422 Maple — week of May 5 update</p>
        <p>Hi Jordan,</p>
        <p>Quick week: we got the old LVP up, subfloor patched at the patio door where it was spongy, and started cement board in the bath. Photos 01–05 walk around the room clockwise from the fridge wall.</p>
        <p>Open item: you wanted the larger format tile in the bath—sample board is in pic 04 on the bench. If that is a go, we will order Monday so we are not burning a week.</p>
        <p>Next week: set bath floor, start kitchen cabinets Tuesday if delivery shows up on time (I will text if it slides).</p>
        <p>— Chris</p>
    </blockquote>

    <p>If you send this from Job Site Records, you are really exporting a small zip and attaching it—but the email skeleton stays the same.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/use-cases/remodel-progress-photos-for-homeowners.php">Homeowner progress</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Sample weekly homeowner update email',
    'description' => 'Example homeowner email for a remodel weekly update: subject line, short paragraphs, open item, next week.',
    'canonical_path' => '/examples/sample-weekly-homeowner-update-email.php',
    'body' => $body,
]);
