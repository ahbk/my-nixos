# Options
## my-nixos\.backup



Definition of backup targets\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## my-nixos\.backup\.\<name>\.enable



Whether to enable this backup target\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## my-nixos\.backup\.\<name>\.exclude



Paths to exclude from backup



*Type:*
list of string



*Default:*
` [ ] `



*Example:*

```
[
  /home/alex/.cache
]
```

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## my-nixos\.backup\.\<name>\.paths



Paths to backup\.



*Type:*
list of string



*Default:*
` [ ] `



*Example:*

```
[
  /home/alex/.bash_history
  /home/alex/.local/share/qutebrowser/history.sqlite
]
```

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## my-nixos\.desktop-env



Definition of per-user desktop environment\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/desktop-env\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/desktop-env.nix)



## my-nixos\.desktop-env\.\<name>\.enable



Whether to enable desktop environment for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/desktop-env\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/desktop-env.nix)



## my-nixos\.django\.sites



Specification of one or more Django sites to serve



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.enable



Whether to enable a django-app for this host\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.pkgs



The expected django app packages (static and app)\.



*Type:*
attribute set of package

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.port



The port to serve the django-app\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Example:*
` 8000 `

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.ssl



Whether the django-app can assume https or not\.



*Type:*
boolean

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django-svelte\.sites



Specification of one or more Django+SvelteKit sites to serve



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.django-svelte\.sites\.\<name>\.enable



Whether to enable Django+SvelteKit site…



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.django-svelte\.sites\.\<name>\.pkgs\.django



Django packages



*Type:*
attribute set of package

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.django-svelte\.sites\.\<name>\.pkgs\.svelte



Svelte packages



*Type:*
attribute set of package

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.django-svelte\.sites\.\<name>\.ports



Two ports



*Type:*
list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Example:*

```
[
  8000
  8001
]
```

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.django-svelte\.sites\.\<name>\.ssl



HTTPS



*Type:*
boolean

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.fastapi\.sites



Specification of one or more FastAPI sites to serve



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi\.sites\.\<name>\.enable



Whether to enable a fastapi-app for this host\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi\.sites\.\<name>\.pkgs



The expected fastapi-app packages\.



*Type:*
attribute set of package

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi\.sites\.\<name>\.port



The port to serve the fastapi-app\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Example:*
` 8000 `

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi\.sites\.\<name>\.ssl



Whether the fastapi-app can assume https or not\.



*Type:*
boolean

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi-svelte\.sites



Specification of one or more FastAPI+SvelteKit sites to serve



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.fastapi-svelte\.sites\.\<name>\.enable



Whether to enable fastapi-svelte\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.fastapi-svelte\.sites\.\<name>\.pkgs\.fastapi



fastapi packages



*Type:*
attribute set of package

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.fastapi-svelte\.sites\.\<name>\.pkgs\.svelte



svelte packages



*Type:*
attribute set of package

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.fastapi-svelte\.sites\.\<name>\.ports



two ports



*Type:*
list of 16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Example:*

```
[
  8000
  8001
]
```

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.fastapi-svelte\.sites\.\<name>\.ssl



HTTPS



*Type:*
boolean

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.glesys\.updaterecord\.enable



Whether to enable DNS-record on glesys\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/glesys-updaterecord\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/glesys-updaterecord.nix)



## my-nixos\.glesys\.updaterecord\.cloudaccount



The glesys account id



*Type:*
string

*Declared by:*
 - [modules/glesys-updaterecord\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/glesys-updaterecord.nix)



## my-nixos\.glesys\.updaterecord\.device



The device that should be watched\.



*Type:*
string

*Declared by:*
 - [modules/glesys-updaterecord\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/glesys-updaterecord.nix)



## my-nixos\.glesys\.updaterecord\.recordid



The glesys id of the record



*Type:*
string

*Declared by:*
 - [modules/glesys-updaterecord\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/glesys-updaterecord.nix)



## my-nixos\.hm



Set of users to be configured with home-manager



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/hm\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/hm.nix)



## my-nixos\.hm\.\<name>\.enable



Whether to enable home-manager for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/hm\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/hm.nix)



## my-nixos\.ide



Set of users to be configured with IDE\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/ide\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/ide.nix)



## my-nixos\.ide\.\<name>\.enable



Whether to enable IDE for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/ide\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/ide.nix)



## my-nixos\.ide\.\<name>\.mysql



Whether to enable a mysql db with same name\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/ide\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/ide.nix)



## my-nixos\.ide\.\<name>\.postgresql



Whether to enable a postgres db with same name\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/ide\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/ide.nix)



## my-nixos\.ide\.\<name>\.userAsTopDomain



Whether to enable username a top domain name in local network\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/ide\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/ide.nix)



## my-nixos\.laptop\.enable



Whether to enable Enable power management on the host\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/laptop\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/laptop.nix)



## my-nixos\.mailClient



Set of users to be configured with mail client\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/mail-client\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mail-client.nix)



## my-nixos\.mailClient\.\<name>\.enable



Whether to enable a mail client for user…



*Type:*
boolean



*Default:*
` true `



*Example:*
` true `

*Declared by:*
 - [modules/mail-client\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mail-client.nix)



## my-nixos\.mailServer\.enable



Whether to enable mail server…



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/mail-server\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mail-server.nix)



## my-nixos\.mysql



Specification of one or more mysql user/database pair to setup



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/mysql\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mysql.nix)



## my-nixos\.mysql\.\<name>\.ensure



Ensure mysql database for the user



*Type:*
boolean



*Default:*
` true `

*Declared by:*
 - [modules/mysql\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mysql.nix)



## my-nixos\.nginx\.enable



Whether to enable nginx web server…



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/nginx\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/nginx.nix)



## my-nixos\.nginx\.email



Email for ACME certificate updates



*Type:*
string

*Declared by:*
 - [modules/nginx\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/nginx.nix)



## my-nixos\.postgresql



Specification of one or more postgresql user/database pair to setup



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/postgresql\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/postgresql.nix)



## my-nixos\.postgresql\.\<name>\.ensure



Ensure a postgresql database for the user\.



*Type:*
boolean



*Default:*
` true `

*Declared by:*
 - [modules/postgresql\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/postgresql.nix)



## my-nixos\.shell



Set of users to be configured with shell



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/shell\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/shell.nix)



## my-nixos\.shell\.\<name>\.enable



Whether to enable shell for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/shell\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/shell.nix)



## my-nixos\.svelte\.sites



Specification of one or more Svelte sites to serve



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.svelte\.sites\.\<name>\.enable



Whether to enable svelte-app for this host…



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.svelte\.sites\.\<name>\.api



URL for the API endpoint



*Type:*
string

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.svelte\.sites\.\<name>\.api_ssr



Server side URL for the API endpoint



*Type:*
string

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.svelte\.sites\.\<name>\.location



URL path to serve the application\.



*Type:*
string



*Default:*
` "" `

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.svelte\.sites\.\<name>\.pkgs



The expected svelte app packages\.



*Type:*
attribute set of package

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.svelte\.sites\.\<name>\.port



Port to serve the application\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.svelte\.sites\.\<name>\.ssl



Whether the svelte-app can assume https or not\.



*Type:*
boolean

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.user



Set of users to be configured\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/user.nix)



## my-nixos\.user\.\<name>\.enable



Whether to enable this user\.



*Type:*
boolean



*Default:*
` true `



*Example:*
` true `

*Declared by:*
 - [modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/user.nix)



## my-nixos\.user\.\<name>\.email



User email\.



*Type:*
string

*Declared by:*
 - [modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/user.nix)



## my-nixos\.user\.\<name>\.groups



User groups\.



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/user.nix)



## my-nixos\.user\.\<name>\.keys



Public SSH keys\.



*Type:*
list of path



*Default:*
` [ ] `

*Declared by:*
 - [modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/user.nix)



## my-nixos\.user\.\<name>\.name



User name\.



*Type:*
string

*Declared by:*
 - [modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/user.nix)



## my-nixos\.user\.\<name>\.uid



User id\.



*Type:*
signed integer

*Declared by:*
 - [modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/user.nix)



## my-nixos\.vd



Set of users to be configured with visual design tools\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/vd\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/vd.nix)



## my-nixos\.vd\.\<name>\.enable



Whether to enable Visual design tools for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/vd\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/vd.nix)



## my-nixos\.wireguard\.wg0\.enable



Whether to enable this host to be part of 10\.0\.0\.0/24\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/wireguard\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/wireguard.nix)



## my-nixos\.wireguard\.wg0\.keepalive



Keepalive interval\.



*Type:*
signed integer



*Default:*
` 25 `

*Declared by:*
 - [modules/wireguard\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/wireguard.nix)



## my-nixos\.wireguard\.wg0\.port



Listening port for establishing a connection\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*
` 51820 `

*Declared by:*
 - [modules/wireguard\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/wireguard.nix)



## my-nixos\.wordpress\.sites



Specification of one or more wordpress sites to serve



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/wordpress\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/wordpress.nix)



## my-nixos\.wordpress\.sites\.\<name>\.enable



Whether to enable wordpress on this host…



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/wordpress\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/wordpress.nix)



## my-nixos\.wordpress\.sites\.\<name>\.basicAuth



Protect the site with basic auth\.



*Type:*
attribute set of string



*Default:*
` { } `

*Declared by:*
 - [modules/wordpress\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/wordpress.nix)



## my-nixos\.wordpress\.sites\.\<name>\.ssl



Enable HTTPS\.



*Type:*
boolean

*Declared by:*
 - [modules/wordpress\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/wordpress.nix)



## my-nixos\.wordpress\.sites\.\<name>\.www



Prefix the url with www\.



*Type:*
boolean



*Default:*
` false `

*Declared by:*
 - [modules/wordpress\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/wordpress.nix)



## my-nixos-hm\.desktop-env\.enable



Whether to enable Desktop Environment for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [hm-modules/desktop-env\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/desktop-env.nix)


