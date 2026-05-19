<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Example</span>
    <h1>Closeout walk order we reuse</h1>
    <p class="lead">Print or keep on a second phone as a checklist. Fictional house “Oak Lane.”</p>

    <ol>
        <li>Front stoop / siding touchups / paint at garage jamb.</li>
        <li>Mudroom: cubbies, shoe bench, outlet behind bench actually reachable.</li>
        <li>Kitchen: toe kick, crown caulk, panel skins, DW power cord not pinched, fridge water drip loop.</li>
        <li>Powder: TP holder height, fan quiet, door stop hits stud not pipe (voice if weird).</li>
        <li>Stairs: handrail returns, skirt scuffs, squeak check slow.</li>
        <li>Primary bath: shower door sweep, niche caulking, grout haze at floor edge.</li>
        <li>Mechanical closet: filter size labeled on return, humidifier drain visible, condensate test if season.</li>
        <li>Attic hatch: ladder, weatherstrip, light works.</li>
        <li>Basement: breaker directory matches test buttons tripped today.</li>
    </ol>

    <p>Shoot each line item only if something is wrong or if the client wants a “green check” album—do not create make-work.</p>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/examples/">All examples</a></li>
        <li><a href="/use-cases/residential-closeout-handover-photos.php">Closeout photos</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Example client closeout photo checklist',
    'description' => 'Reusable residential closeout walk order: exterior, mudroom, kitchen, baths, stairs, mechanical, attic, basement.',
    'canonical_path' => '/examples/example-client-closeout-photo-checklist.php',
    'body' => $body,
]);
