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



Paths to exclude from backup\.



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



## my-nixos\.backup\.\<name>\.privateKeyFile



Location of the private key file used to connect with target\.
Match with a public key in ` my-nixos.users.backup.keys `\.



*Type:*
string



*Default:*
` "/home/backup/.ssh/id_ed25519" `

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## my-nixos\.backup\.\<name>\.pruneOpts



A list of options (–keep-\* et al\.) for ‘restic forget
–prune’, to automatically prune old snapshots\.  The
‘forget’ command is run *after* the ‘backup’ command, so
keep that in mind when constructing the --keep-\* options\.



*Type:*
list of string



*Default:*

```
[
  "--keep-daily 7"
  "--keep-weekly 5"
  "--keep-monthly 12"
  "--keep-yearly 75"
]
```

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## my-nixos\.backup\.\<name>\.timerConfig



When to run the backup\. See [` systemd.timer(5) `](https://www.freedesktop.org/software/systemd/man/systemd.timer.html) for
details\. If null no timer is created and the backup will only
run when explicitly started\.



*Type:*
anything



*Default:*

```
{
  OnCalendar = "01:00";
  Persistent = true;
}
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



Definition of per-domain Django apps to serve\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.enable



Whether to enable Django app\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.locationProxy



Location pattern for proxy to django, empty string -> no proxy



*Type:*
string



*Default:*
` "/" `



*Example:*
` "~ ^/(api|admin)" `

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.locationStatic



Location pattern for static files, empty string -> no static



*Type:*
string



*Default:*
` "/static/" `

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.port



Listening port\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Example:*
` 8000 `

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.ssl



Whether to enable SSL (https) support\.



*Type:*
boolean

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django\.sites\.\<name>\.user



Username for app owner



*Type:*
string

*Declared by:*
 - [modules/django\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django.nix)



## my-nixos\.django-react\.sites



Definition of per-domain Django+React apps to serve\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/django-react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-react.nix)



## my-nixos\.django-react\.sites\.\<name>\.enable



Whether to enable Django+React app\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/django-react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-react.nix)



## my-nixos\.django-react\.sites\.\<name>\.ports



Listening ports\.



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
 - [modules/django-react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-react.nix)



## my-nixos\.django-react\.sites\.\<name>\.ssl



Whether to enable SSL (https) support\.



*Type:*
boolean

*Declared by:*
 - [modules/django-react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-react.nix)



## my-nixos\.django-react\.sites\.\<name>\.user



Username for app owner



*Type:*
string

*Declared by:*
 - [modules/django-react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-react.nix)



## my-nixos\.django-svelte\.sites



Definition of per-domain Django+SvelteKit apps to serve\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.django-svelte\.sites\.\<name>\.enable



Whether to enable Django+SvelteKit app\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.django-svelte\.sites\.\<name>\.ports



Listening ports\.



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



Whether to enable SSL (https) support\.



*Type:*
boolean

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.django-svelte\.sites\.\<name>\.user



Username for app owner



*Type:*
string

*Declared by:*
 - [modules/django-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/django-svelte.nix)



## my-nixos\.fail2ban\.enable



Whether to enable the jails configured with ` services.fail2ban.jails `\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/fail2ban\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fail2ban.nix)



## my-nixos\.fail2ban\.ignoreIP



A list of IP addresses, CIDR masks or DNS hosts not ta ban a host\.



*Type:*
list of string



*Default:*
` [ ] `



*Example:*

```
[
  "10.0.0.0/24"
  "shadowserver.org"
]
```

*Declared by:*
 - [modules/fail2ban\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fail2ban.nix)



## my-nixos\.fastapi\.sites



Definition of per-domain FastAPI apps to serve\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi\.sites\.\<name>\.enable



Whether to enable FastAPI app\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi\.sites\.\<name>\.port



Listening port\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Example:*
` 8000 `

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi\.sites\.\<name>\.ssl



Whether to enable SSL (https) support\.



*Type:*
boolean

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi\.sites\.\<name>\.user



Username for app owner



*Type:*
string



*Default:*
` null `

*Declared by:*
 - [modules/fastapi\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi.nix)



## my-nixos\.fastapi-svelte\.sites



Definition of per-domain FastAPI+SvelteKit apps to serve\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.fastapi-svelte\.sites\.\<name>\.enable



Whether to enable FastAPI+SvelteKit app\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.fastapi-svelte\.sites\.\<name>\.ports



Listening ports\.



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



Whether to enable SSL (https) support\.



*Type:*
boolean

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.fastapi-svelte\.sites\.\<name>\.user



Username for app owner



*Type:*
string

*Declared by:*
 - [modules/fastapi-svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/fastapi-svelte.nix)



## my-nixos\.glesys\.updaterecord\.enable



Whether to enable updating DNS-record on glesys\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/glesys-updaterecord\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/glesys-updaterecord.nix)



## my-nixos\.glesys\.updaterecord\.cloudaccount



Glesys account id\.



*Type:*
string

*Declared by:*
 - [modules/glesys-updaterecord\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/glesys-updaterecord.nix)



## my-nixos\.glesys\.updaterecord\.device



Device that should be watched\.



*Type:*
string



*Example:*
` "enp3s0" `

*Declared by:*
 - [modules/glesys-updaterecord\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/glesys-updaterecord.nix)



## my-nixos\.glesys\.updaterecord\.recordid



The glesys id of the record



*Type:*
string

*Declared by:*
 - [modules/glesys-updaterecord\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/glesys-updaterecord.nix)



## my-nixos\.hm



Set of users to be configured with home-manager\.



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



## my-nixos\.mailserver\.enable



Whether to enable mail server\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/mailserver\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mailserver.nix)



## my-nixos\.mailserver\.domains



List of domains to manage\.



*Type:*
attribute set of (submodule)

*Declared by:*
 - [modules/mailserver\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mailserver.nix)



## my-nixos\.mailserver\.domains\.\<name>\.relay



Enable if this host is the domain’s final destination\.



*Type:*
boolean

*Declared by:*
 - [modules/mailserver\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mailserver.nix)



## my-nixos\.mailserver\.users



Configure user accounts\.



*Type:*
attribute set of (submodule)

*Declared by:*
 - [modules/mailserver\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mailserver.nix)



## my-nixos\.mailserver\.users\.\<name>\.enable



Whether to enable this user\.



*Type:*
boolean



*Default:*
` true `



*Example:*
` true `

*Declared by:*
 - [modules/mailserver\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mailserver.nix)



## my-nixos\.mailserver\.users\.\<name>\.catchAll



Make the user recipient of a whole domain\.



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [modules/mailserver\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/mailserver.nix)



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



## my-nixos\.react\.sites



Specification of one or more React sites to serve



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/react.nix)



## my-nixos\.react\.sites\.\<name>\.enable



Whether to enable react-app for this host…



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/react.nix)



## my-nixos\.react\.sites\.\<name>\.api



URL for the API endpoint



*Type:*
string

*Declared by:*
 - [modules/react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/react.nix)



## my-nixos\.react\.sites\.\<name>\.location



URL path to serve the application\.



*Type:*
string



*Default:*
` "/" `

*Declared by:*
 - [modules/react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/react.nix)



## my-nixos\.react\.sites\.\<name>\.ssl



Whether the react-app can assume https or not\.



*Type:*
boolean

*Declared by:*
 - [modules/react\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/react.nix)



## my-nixos\.sendmail



Set of users to be configured with sendmail\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/sendmail\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/sendmail.nix)



## my-nixos\.sendmail\.\<name>\.enable



Whether to enable sendmail…



*Type:*
boolean



*Default:*
` true `



*Example:*
` true `

*Declared by:*
 - [modules/sendmail\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/sendmail.nix)



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
` "/" `

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



## my-nixos\.svelte\.sites\.\<name>\.user



Username for app owner



*Type:*
string

*Declared by:*
 - [modules/svelte\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/svelte.nix)



## my-nixos\.users



Set of users to be configured\.



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/users\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/users.nix)



## my-nixos\.users\.\<name>\.enable



Whether to enable this user\.



*Type:*
boolean



*Default:*
` true `



*Example:*
` true `

*Declared by:*
 - [modules/users\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/users.nix)



## my-nixos\.users\.\<name>\.aliases



Emails this user manages\.



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [modules/users\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/users.nix)



## my-nixos\.users\.\<name>\.email



User email\.



*Type:*
string

*Declared by:*
 - [modules/users\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/users.nix)



## my-nixos\.users\.\<name>\.groups



User groups\.



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [modules/users\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/users.nix)



## my-nixos\.users\.\<name>\.keys



Public SSH keys\.



*Type:*
list of path



*Default:*
` [ ] `

*Declared by:*
 - [modules/users\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/users.nix)



## my-nixos\.users\.\<name>\.name



User name\.



*Type:*
string

*Declared by:*
 - [modules/users\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/users.nix)



## my-nixos\.users\.\<name>\.uid



User id\.



*Type:*
signed integer

*Declared by:*
 - [modules/users\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/users.nix)



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



## my-nixos-hm\.ide\.enable



Whether to enable IDE for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [hm-modules/ide\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/ide.nix)



## my-nixos-hm\.ide\.email



Email for git\.



*Type:*
string

*Declared by:*
 - [hm-modules/ide\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/ide.nix)



## my-nixos-hm\.ide\.name



Name for git\.



*Type:*
string

*Declared by:*
 - [hm-modules/ide\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/ide.nix)



## my-nixos-hm\.shell\.enable



Whether to enable Enable shell for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [hm-modules/shell\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/shell.nix)



## my-nixos-hm\.user\.enable



Whether to enable home-manager for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [hm-modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/user.nix)



## my-nixos-hm\.user\.name



Name for the user\.



*Type:*
string

*Declared by:*
 - [hm-modules/user\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/user.nix)



## my-nixos-hm\.vd\.enable



Whether to enable Enable visual design tools for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [hm-modules/vd\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/vd.nix)


