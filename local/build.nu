#!/usr/bin/env nu

# Compile en local les cibles déclarées dans build.yaml.
#
# build.yaml reste la seule source de vérité : ce script la lit, il ne
# redéclare rien. Ajouter une cible là-bas suffit.
#
#     nu local/build.nu              toutes les cibles
#     nu local/build.nu dongle       celles dont le nom contient « dongle »
#     nu local/build.nu --propre     repartir de zéro

def main [
    filtre?: string   # ne compiler que les cibles dont l'artefact contient ce texte
    --propre          # supprimer les répertoires de compilation d'abord
] {
    let racine = ($env.FILE_PWD | path dirname)
    let west = $"($racine)/.venv/bin/west"
    if not ($west | path exists) {
        error make {msg: "espace de travail absent — lance d'abord : nu local/setup.nu"}
    }

    let cibles = (
        open $"($racine)/build.yaml"
        | get include
        | where {|c| $filtre == null or ($c.artifact-name | str contains $filtre) }
    )
    if ($cibles | is-empty) { error make {msg: $"aucune cible ne correspond à « ($filtre) »"} }

    let sortie = $"($racine)/build/firmware"
    if $propre { rm -rf $"($racine)/build" }
    mkdir $sortie

    cd $racine
    for c in $cibles {
        let dossier = $"($racine)/build/($c.artifact-name)"
        print $"── ($c.artifact-name)"

        mut args = [build -s zmk/app -d $dossier -b $c.board]
        if ($c | get -o snippet | is-not-empty) { $args = ($args | append [-S $c.snippet]) }
        $args = ($args | append [-- $"-DSHIELD=($c.shield)" $"-DZMK_CONFIG=($racine)/config"])
        if ($c | get -o cmake-args | is-not-empty) { $args = ($args | append ($c.cmake-args | split row " ")) }

        ^$west ...$args

        let uf2 = $"($dossier)/zephyr/zmk.uf2"
        if ($uf2 | path exists) {
            cp $uf2 $"($sortie)/($c.artifact-name).uf2"
            print $"   ✔ ($c.artifact-name).uf2"
        } else {
            print "   ✘ pas de .uf2 produit"
        }
    }

    print ""
    print $"Firmwares dans ($sortie) :"
    ls $sortie | select name size | each {|f| {fichier: ($f.name | path basename), taille: $f.size} } | to md --pretty | print
}
