#
# Local module
#
# Compilation locale du firmware ZMK, sans passer par GitHub Actions.
#
#     use local
#     local          # ce que ce module sait faire
#     local setup    # une fois : prépare l espace de travail
#     local build    # à chaque fois : compile

#
# ZMK Build Utilities
#
export def main [
  --find (-f): string # string to find in command names
] {
  let cmds = [
    [commande, rôle];
    ["local setup" "prépare l espace de travail west et la chaîne ARM — une seule fois"]
    ["local build" "compile les cibles de build.yaml et rassemble les .uf2"]
    ["local build <filtre>" "ne compile que les cibles dont le nom contient le filtre"]
    ["local build --propre" "repart de zéro"]
  ]
  if $find == null { $cmds } else { $cmds | where {|c| $c.commande =~ $find } }
}

# `path self` se résout à l'analyse du fichier, contrairement à $env.FILE_PWD
# qui n'existe pas à l'exécution d'une commande du module.
const RACINE = (path self ..)

# Prepare the local build workspace — run once
export def setup [] {
    let r = $RACINE

    print "── prérequis système ──"
    let manquants = (
        [cmake gperf dtc ccache]
        | where {|p| (do -i { ^pacman -Q $p } | complete | get exit_code) != 0 }
    )
    if ($manquants | is-not-empty) {
        print $"  ✘ manquants : ($manquants | str join ', ')"
        print $"    lance :  omarchy pkg add ($manquants | str join ' ')"
        error make {msg: "prérequis système absents"}
    }
    print "  ✔ cmake, gperf, dtc, ccache"

    print ""
    print "── west, dans un environnement isolé ──"
    let venv = $"($r)/.venv"
    if not ($venv | path exists) { ^uv venv $venv }
    ^uv pip install --python $"($venv)/bin/python" west
    let west = $"($venv)/bin/west"
    print "  ✔ west"

    print ""
    print "── espace de travail west ──"
    print "  Premier passage : plus de 2 Go, compter un quart d heure."
    print "  git reste longtemps affiche a 0% en decompressant : ce n est pas un blocage."
    if not ($"($r)/.west" | path exists) { ^$west init -l $"($r)/config" }
    cd $r
    ^$west update --fetch-opt=--filter=tree:0
    ^$west zephyr-export

    print ""
    print "── SDK Zephyr, chaîne ARM seule ──"
    ^$west sdk install -t arm-zephyr-eabi

    print ""
    print "✅ Prêt.  local build"
}

# Build the firmware declared in build.yaml
export def build [
    filtre?: string   # ne compiler que les cibles dont l artefact contient ce texte
    --propre          # supprimer les répertoires de compilation d abord
] {
    let r = $RACINE
    let west = $"($r)/.venv/bin/west"
    if not ($west | path exists) {
        error make {msg: "espace de travail absent — lance d abord : local setup"}
    }

    let cibles = (
        open $"($r)/build.yaml"
        | get include
        | where {|c| $filtre == null or ($c.artifact-name | str contains $filtre) }
    )
    if ($cibles | is-empty) { error make {msg: $"aucune cible ne correspond à ($filtre)"} }

    if $propre { rm -rf $"($r)/build" }
    let sortie = $"($r)/build/firmware"
    mkdir $sortie
    cd $r

    for c in $cibles {
        let dossier = $"($r)/build/($c.artifact-name)"
        print $"── ($c.artifact-name)"

        mut args = [build -s zmk/app -d $dossier -b $c.board]
        if ($c | get -o snippet | is-not-empty) { $args = ($args | append [-S $c.snippet]) }
        $args = ($args | append [-- $"-DSHIELD=($c.shield)" $"-DZMK_CONFIG=($r)/config"])
        if ($c | get -o cmake-args | is-not-empty) {
            $args = ($args | append ($c.cmake-args | split row " "))
        }
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
    ls $sortie | each {|f| {fichier: ($f.name | path basename), taille: $f.size} } | to md --pretty
}
