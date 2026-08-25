# App Store listing — Français (fr-FR)

App Store Connect → Notepad Classic → fr-FR. Uploaded via the App Store Connect API for v1.2.9.
Limits: app name 30, subtitle 30, promotional text 170, keywords 100, description 4000.

## Subtitle (26/30)
Sans IA. Onglets. Reprise.

## Promotional Text (138/170)
Bloc-notes texte brut pour Mac : sans IA, sans compte, sans cloud. Onglets et reprise de session gardent vos notes. UTF-8, EUC-KR, UTF-16.

## Keywords (81/100)
bloc-notes,editeur de texte,texte brut,encodage,onglets,notes,editeur,txt,unicode

## Description (1856/4000)
Un éditeur de texte brut rapide et privé pour macOS. Pour qui vient du Bloc-notes de Windows comme pour qui veut les onglets et la reprise que TextEdit n'offre pas.

Pas d'IA. Pas de compte. Pas de cloud obligatoire. Du texte, rien d'autre.

Reprise automatique de la session
Quittez l'application avec vos onglets ouverts, y compris les notes non enregistrées : au lancement suivant, même après un redémarrage, tout revient à l'identique. Les réglages permettent de choisir entre reprendre la session précédente ou en commencer une nouvelle.

Plusieurs onglets
Travaillez sur plusieurs documents dans une fenêtre. Réorganisez par glissement, changez avec Ctrl-Tab ; les onglets non enregistrés portent un *.

Encodages
Ouvre et enregistre en UTF-8, UTF-8 avec BOM, EUC-KR et UTF-16 (LE/BE). Depuis la barre d'état, vous pouvez réouvrir avec un autre encodage ou convertir le contenu, et un avertissement clair signale les caractères impossibles à représenter.

Orthographe et correction
Utilise les dictionnaires système de macOS, sans réseau. La correction automatique est facultative et la vérification peut être désactivée pour les extensions de code ou de journaux.

Aperçu facultatif
Aperçu de .md et .html côte à côte ou en plein écran. Aucun script n'est exécuté. Les images et le CSS distants ne sont chargés qu'après autorisation dans cet onglet.

Et aussi
• Rechercher et remplacer en ligne, nombre de correspondances, respect de la casse
• Coloration Markdown, JSON, XML, HTML et journaux
• Impression, aller à la ligne, insertion de l'heure et de la date, retour à la ligne, zoom
• Plusieurs fenêtres, mode clair et sombre, interface en 16 langues

Confidentialité
Fonctionne dans un sandbox complet, sans publicité, et ne collecte aucune donnée. Le réseau n'est utilisé que dans les onglets où vous autorisez les images distantes de l'aperçu.

## What's New — v1.2.9 (1138/4000)
Corrections à l'ouverture et à la fermeture des fichiers.

• Ouvrir un document depuis le Finder ne lui ajoute plus l'attribut de quarantaine de macOS. Auparavant, la simple lecture suffisait à l'ajouter alors que rien n'était écrit, et le Finder demandait ensuite de vérifier le fichier à chaque ouverture, avec cette app ou une autre. L'ouverture ne fait plus que lire ; le fichier n'est écrit qu'à l'enregistrement.

• Un fichier qui refusait de s'ouvrir s'ouvre. Si un onglet ne pouvait pas être restauré au lancement, réouvrir ce fichier basculait simplement vers l'onglet vide sans le lire.

• Un même fichier atteint par un autre chemin — variante de casse ou lien symbolique — ne s'ouvre plus en deux onglets qui s'écrasent mutuellement.

• Saisir du texte dans un onglet dont le fichier n'a pas pu être lu ne contourne plus l'avertissement avant de remplacer l'original.

• Fermer le dernier onglet ferme la fenêtre. Avant, rien ne semblait se produire.

• Ouvrir un fichier ne laisse plus un onglet « Sans titre » vide à côté.

• Les échecs d'enregistrement indiquent la cause réelle au lieu de toujours demander un emplacement.
