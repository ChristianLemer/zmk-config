#!/usr/bin/env nu

# Prépare la compilation locale — à lancer une fois.
#
# Tout reste dans ce dépôt et dans ton dossier personnel : ni groupe docker,
# ni service système. Les répertoires téléchargés sont dans .gitignore.
#
# Prérequis à installer une fois, avec sudo :
#     omarchy pkg add cmake gperf dtc ccache

def main [] {
    let racine = ($env.FILE_PWD | path dirname)

    print "── vérification des prérequis système ──"
    let manquants = (
        [cmake gperf dtc ccache]
        | where {|p| (do -i { ^pacman -Q $p } | complete | get exit_code) != 0 }
    )
    if ($manquants | is-not-empty) {
        print $"  ✘ manquants : ($manquants | str join ', ')"
        print "    lance :  omarchy pkg add ($manquants | str join ' ')"
        error make {msg: "prérequis système absents"}
    }
    print "  ✔ cmake, gperf, dtc, ccache"

    print ""
    print "── environnement Python isolé ──"
    let venv = $"($racine)/.venv"
    if not ($venv | path exists) { ^uv venv $venv }
    ^uv pip install --python $"($venv)/bin/python" west
    print "  ✔ west"

    let west = $"($venv)/bin/west"

    print ""
    print "── espace de travail west ──"
    print "  Premier passage : environ 1,5 Go à télécharger, quelques minutes."
    if not ($"($racine)/.west" | path exists) {
        ^$west init -l $"($racine)/config"
    }
    cd $racine
    ^$west update --fetch-opt=--filter=tree:0
    ^$west zephyr-export

    print ""
    print "── SDK Zephyr, uniquement la chaîne ARM ──"
    ^$west sdk install -t arm-zephyr-eabi

    print ""
    print "✅ Prêt. Compiler :  nu local/build.nu"
}
