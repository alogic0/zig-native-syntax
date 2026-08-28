<article>
<?php
namespace App\Http\Controllers;

#[Route('/users/{id}', methods: ['GET'])]
final class UserController extends Controller
{
    public function __invoke(Request $request): Response
    {
        $render = function (User $user) use ($request) { return $user->name; };
        $template = <<<HTML
<section><?= $request->name ?></section>
HTML;
        $literal = 'not ?> closed';
        return new Response($render($request->user), $template, $literal);
    }
}
?>
<footer>Done</footer>
