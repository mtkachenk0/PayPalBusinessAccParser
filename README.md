```sh
sudo apt-get install $(grep -vE "^\s*#" apt-get_requirements.txt  | tr "\n" " ")
sudo gem install $(grep -vE "^\s*#" gem-requirements.txt  | tr "\n" " ")
----
install chromedriver...
create symlink to /usr/local/bin/chromedriver
```