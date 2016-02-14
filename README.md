<style type="text/css">
    ol ol{ list-style-type: lower-alpha; }
</style>

Author:
   Benjamin Kellermann <Benjamin dot Kellermann at gmx in Germany>

License: 
   GNU AGPL v3 or higher
   see file License
   
## Requirements
 * ruby >=1.8
 * git >=1.6.5 (preferred and default setting) or bzr
 * libgettext-ruby (for localization)
 * gettext (for generating localization files)
 

 
## Installation
1. Place this application into a directory where cgi-scripts are evaluated.
2. If you want to change some configuration, state it in the file »config.rb«
   (see config_sample.rb for help)
   to start with a default configuration.
3. The webserver needs the permission to write into the directory 
4. You need .mo files in order to use localisations. 
   You have 2 possibilities:
    
    a. Run this small script to fetch the files from the main server:
      
      ```bash
      cd $DUDLE_INSTALLATION_PATH
      for i in locale/??; do
      	wget -O $i/dudle.mo https://dudle.inf.tu-dresden.de/locale/`basename $i`/dudle.mo
      done
      ```
    b. Build them on your own. This requires gettext, libgettext-ruby-util, potool, and make to be installed.
      
      ```bash
      sudo aptitude install gettect libgettext-ruby-util potool make
      make
      ```
5. In order to let access control work correctly, the webserver needs 
   auth_digest support. It therefore may help to type:
   
   ```bash
   sudo a2enmod auth_digest
   ```
6. In order to get atom-feed support you need ruby-ratom to be installed. E.g.:
   
   ```bash
   sudo aptitude install rubygems ruby-dev libxml2-dev zlib1g-dev
   sudo gem install ratom
   ```
7. for RUBY 1.9 you need to add 
   
   ```bash
   SetEnv RUBYLIB $DUDLE_INSTALLATION_PATH
   ```
   to your .htaccess
8. to make titles with umlauts working you need to set the encoding e.g. by adding
   
   ```bash
   SetEnv RUBYOPT "-E UTF-8:UTF-8"
   ```
   to your .htaccess
9. It might be the case, that you have to set some additional Variables in your .htaccess:
   	
   	```bash
    SetEnv GIT_AUTHOR_NAME="http user"
    SetEnv GIT_AUTHOR_EMAIL=foo@example.org
    SetEnv GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
    SetEnv GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
    ```
10. Try to open http://$YOUR_SERVER/check.cgi to check if your config seems to work.
 
## Pimp your Installation
 * If you want to create your own Stylesheet, you just have to put it in
   the folder »$DUDLE_HOME_FOLDER/css/«. Afterwards you may config this one
   to be the default Stylesheet. Examples can be found here:
     https://dudle.inf.tu-dresden.de/css/
   This is a bazaar repository as well, so you may branch it if you want…
   
   ```bash
   cd $DUDLE_HOME_FOLDER/css
   bzr branch https://dudle.inf.tu-dresden.de/css/ .
   ```
   Send me your Stylesheet if you want it to appear at 
   https://dudle.inf.tu-dresden.de
 * If you want to extend the functionality you might want to place a file
   »main.rb« in $DUDLE_HOME_FOLDER/extension/$YOUR_EXTENSION/main.rb
   Examples can be found here:
     https://dudle.inf.tu-dresden.de/unstable/extensions/
     which again are repositories ;--) e.g.:
    
     ```bash
     cd $DUDLE_HOME_FOLDER/dudle/extensions/
     bzr branch https://dudle.inf.tu-dresden.de/unstable/extensions/10_participate/
     bzr branch https://dudle.inf.tu-dresden.de/unstable/extensions/symcrypt/
     ```

## Translators
If you set $DUDLE_POEDIT_AUTO to your lang, poedit will launch automatically when building the application.
E.g.:

```bash
export DUDLE_POEDIT_AUTO=fr
bzr pull
make # will launch poedit if new french strings are to be translated
```
