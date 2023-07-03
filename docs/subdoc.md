# Description
\
\
Un fichier submit peut faire appel a toutes les commandes du shell a
l'exception des commandes internes suivantes:

- help
- pwd

qui ne sont pas encore supportees.

Les commandes **call**,**chain**,**choice**
,**cls**,**getkey**,**goto**,**if**,**on** **error**,
**pause**,**restore**,**return**,**save** et **type** ont ete ajoutees.

La commande **echo** est etendue par rapport a celle du shell.

Une ligne ne peut exceder *128* caracteres ou *200* apres expansion des variables.

Il n'y a ^Bpas de taille maximale^G pour un fichier submit.
# Description
\
\
Les parametres de la ligne de commande sont accessibles par les variables^C$0^G a^C$9^G.

^C$0^G est le nom du fichier submit.


Les lignes commencant par **REM** ,  ^T#^P , ^T;^P sont des commentaires.

Les lignes commencant par ^T:^P definissent un label.
\
\
\
\
\
\
\
\
\
\
\
# Call
\
\
La commande **call** permet de faire
appel a une sous-routine terminee
par **return**.
\
\
## Syntaxe:^P
call^Flabel
\
\
\
\
\
\
\
\
\
\
\
\
\
\
# Chain
\
\
La commande **chain** permet de poursuivre
l'execution a partir d'un autre script.
\
\
## Syntaxe:^P
chain ^Efilename

En cas d'erreur ^D^Rerrorlevel^G^Pvaut 1
et le script appelant se poursuit.


## Exemple:^P
- chain script.sub
\
\
\
\
\
\
\
\
# Choice
\
\
La commande **choice** permet d'afficher
un message et de proposer une liste
d'options.
\
\
## Syntaxe:^P
choice ^B[-n] [-c<liste>] [msg]

## Options:^P
- ^B-n^G n'affiche pas les choix
- ^B<liste>^G est une suite de caracteres composant les options possibles. Valeur par defaut: YN
- ^Bmsg^G est le message affiche. Valeur par defaut: aucun

## Exemples:^P
- choice -con Continuer
\
\
\
# Echo
\
\
La commande **echo** accepte les caracteres de controle.

Par exemple pour la couleur:

^@^WNoir ^P
^ARouge
^BVert
^CJaune
^DBleu
^EMagenta
^FCyan
 Blanc

  noir
^Qrouge ^P
^@^Rvert ^P
^@^Sjaune ^P
^Tbleu ^P
^Umagenta ^P
^D^Vcyan ^P
^@^Wblanc ^P

Les caracteres de controles sont \^ A a \^[

## Syntaxe:^P
- echo ^B[-n] [message]

## Options:^P
- ^B-n^G ne fait pas de saut de ligne a la suite du message
\
\
# Getkey
\
\
La commande **getkey** permet d'attendre
la frappe d'une touche du clavier.

Le code ASCII de la touche est place
dans la variable^D^Rkey ^P^@.
\
\
## Syntaxe:^P
getkey
\
\
\
\
\
\
\
\
\
\
\
\
# Goto
\
\
La commande **goto** permet de poursuivre
l'execution a un label specifique.

Un label est cree en debutant une ligne
par^F:^Gsuivi d'une chaine de caracteres.
\
\
## Syntaxe:^P
goto^Flabel
\
\
\
\
\
\
\
\
\
\
\
\
# If  (1/2)
\
\
La commande **if** permet de faire
un test par rapport au code erreur de
la derniere commande executee ou de
tester l'existence d'un fichier.
\
\
## Syntaxe:^P
- if ^D^Rvar^C^Pn^Finstruction
- if exist^Efichier^Finstruction
- if ^D^Rvar^B^Pop^Cn^Finstruction
\
Si la valeur de ^D^Rvar^G^Pest superieure ou egale a^Cn^Gou si le fichier
existe alors^Finstruction^Gsera executee.

^D^Rvar^G^P peut etre errorlevel ou key

^Bop^Gpeut etre <, =, > ou #
\
# If  (2/2)
\
\
### Exemples:^P
- [1] if errorlevel 2 goto choix2
- [2] if exist fichier echo Ok
- [3] if errorlevel < 2 echo inferieur
- [4] if key # 65 echo different
\
\
[1] Ira au label^Fchoix2^Gsi^D^Rerrorlevel ^P^G est superieur ou egale a^C2^G.

[2] Affiche^BOk^Gsi^Efichier^Gexiste.

[3] Affiche^Binferieur^Gsi^D^Rerrorlevel ^P^G est inferieur a^C2^G.

[4] Affiche^Bdifferent^Gsi^D^Rkey ^P^G est different de^C65^G.
\
\
\
\
# Input (1/2)
\
\
La commande **input** affiche un message
et attend la saisie d'une chaine de caracteres.
\
## Syntaxe:^P
^Pinput^B[msg],[len],^D^Rvar^G^P
\
## Parametres:^P
- ^Bmsg^G est le message affiche.
- Valeur par defaut: aucun
\
- ^Blen^G est la longueur du champ.
- Valeur par defaut: 32
- Valeur maximale  : 32
\
- ^D^Rvar^G^P   est le nom de la variable.
\
\
\
\
# Input (2/2)
\
\
Apres execution^D^Rerrorlevel^G^Pvaut:
\
- 0: ok
- 1: saisie vide
- 2: sortie par ctrl+c
\
\
### Exemples:^P
\
- input "choix ",10,var
- imput "",,var
\
\
\
\
\
\
\
\
\
# On error (1/2)
\
\
La commande **on error** permet d'intercepter les erreurs d'execution
qui normalement mettent fin au script.
\
La portee de **on error** s'etend jusqu'a l'execution de la prochaine instruction **on error**.
\
## Syntaxe:^P
^Pon error^B[instruction]
\
## Parametre:^P
- ^Binstruction^Gest l'instruction qui sera executee en cas d'erreur.
Si^Binstruction^Gest absent, submit revient au comportemment par defaut et la prochaine erreur provoquera un arret du script.
\
# On error (2/2)
\
\
### Exemples:^P
\
- 1. on error goto^Flabel1
- 2. on error call^Fsubr1
- 3. on error echo^B"Erreur $errorlevel"
- 4. on error ^T; ignore^P
- 5. on error
\
 1) Saute au label^Flabel1.

 2) Execute la procedure^Fsubr1^Gpuis continue a la ligne suivant celle qui a provoque l'erreur.

 3) Affiche ^BErreur xx^Gpuis continue a la ligne suivant celle qui a provoque l'erreur.

 4) Ignore les erreurs.

 5) Revient au comportement par defaut.

# Pause
\
\
La commande **pause** affiche un message et attend l'appui sur une touche.

Elle accepte un message optionnel en parametre.
\
\
\
\
## Syntaxe:^P
pause^B[message]

Le message par defaut est:

      ^LPress any key to continue
\
\
\
\
\
\
# Restore (1/2)
\
\
La commande **restore from** permet
de recharger des variables a partir
d'un fichier (voir **save to**).
\
Elle necessite le nom du fichier en
parametre.
\
\
## Syntaxe:^P
restore from^Efilename
\
\
\
\
\
\
\
\
\
\
# Restore (2/2)
\
\
Apres execution^D^Rerrorlevel^G^Pvaut:
\
- 0: ok
- 1: erreur d'ouverture du fichier
- 2: '=' manquant
- 3: nom de variable trop long
- 4: trop de variables
- 5: chaine trop longue
- 6: erreur interne
\
### Exemple:^P
\
- restore from variable.cfg
\
\
\
\
\
\
\
# Return
\
\
La commande **return** termine une
sous-routine et permet de revenir a la
ligne suivant le **call**.

## Syntaxe:^P
return
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
# Save
\
\
La commande **save to** permet de
sauvegarder les variables en cours dans
un fichier (voir **restore from**).
\
Elle necessite le nom du fichier en parametre.
\
##  Syntaxe:^Psave to^Efilename
\
Apres execution^D^Rerrorlevel^G^Pvaut:
\
- 0: ok
- 1: erreur d'ouverture du fichier
\
### Exemple:^P
\
- save to variable.cfg
\
# Text (1/2)
\
\
Affiche directement tout ce qui est entre **text** et **endtext**
\
Cela permet d'afficher un texte ou un formulaire plus simplement qu'avec
la commande **echo**
\
Les codes de controles sont interpretes ainsi que les parametres du script.
\
**text** et **endtext** doivent etre seuls sur la ligne.
\
\
\
\
\
\
\
# Text (2/2)
\
\
### Exemple:^P

text

Ligne de texte

avec des^[Bcouleurs^[G

endtext
\
\
^Taffiche:^P

Ligne de texte

avec des^Bcouleurs^G
\
\
\
\
\
# Type
\
\
La commande **type** est un alias de **cat**
mais renvoie une erreur si son parametre est absent.

## Syntaxe:^P
type ^Efichier

