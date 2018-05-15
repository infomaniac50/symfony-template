#!/bin/bash

# Utility Functions
# https://www.gitignore.io/
function gi() { curl -L -s https://www.gitignore.io/api/\$@ ;}

# Constants
# You should change these.

# How would you identify this package in composer/node?
# URL friendly characters only.
PROJECT_NAME=symfony-template

# I usually don't give this too much thought.
# Leave as is if you don't want to deal with it right now.
PROJECT_DESCRIPTION="Your project description."

# https://getcomposer.org/doc/04-schema.md#license
# https://spdx.org/licenses/
PROJECT_LICENSE="MIT"

GIT_REPOSITORY="git@github.com:infomaniac50/symfony-template.git"

DEPLOYMENT_DIRECTORY="${HOME}/${PROJECT_NAME}"
DEPLOYMENT_HOSTNAME="yourserver.example.com"
DEPLOYMENT_USERNAME="johndoe"

# How would you identify yourself if you had a composer/node package?
# Sidenote: NPM has scoped packages. Use @<vendor> to scope your packages.
# https://docs.npmjs.com/misc/scope Neat isn't it.
# URL friendly characters only.
VENDOR=infomaniac50

# Does what it says on the tin.
YOUR_NAME="Derek Chafin"
# Ditto
YOUR_EMAIL="infomaniac50@users.noreply.github.com"

# I like www because it jives with old school Apache.
# It's not the html directory but it contains related stuff.
APPLICATION_DIRECTORY=www

# Any serious project will have a documentation site to go along with it.
DOCUMENATION_DIRECTORY=docs
# End Constants

# Setup Scripts
# You don't have to touch anything below this line. Probably.

echo "I like the Learn theme. https://learn.netlify.com/en/"
echo "Use this command to add it."
echo "git subomdule add https://github.com/matcornic/hugo-theme-learn.git docs/themes/hugo-theme-learn"
echo "Or use another theme from https://themes.gohugo.io/"
set -x

# Generate some serious documentation for a serious project.
# hugo will create the directory if it doesn't exist but I like to be thorough.
mkdir -p $DOCUMENATION_DIRECTORY
hugo new site $DOCUMENATION_DIRECTORY

# composer will create the directory if it doesn't exist but I like to be thorough.
mkdir -p $APPLICATION_DIRECTORY
composer create-project symfony/website-skeleton $APPLICATION_DIRECTORY 4.*

# composer create-project uses git clone to fetch the skeleton.
# Remove the .git directory so it can be tracked from the parent.
rm -rf $APPLICATION_DIRECTORY/.git/

# You probably got this from git clone.
rm -rf .git/
# I use git. If you don't use git then you can replace this or delete it.
# You will have to update your vcs ignore files too.
git init

# Ignore composer stuff in git.
gi composer > .gitignore

# http://tldp.org/LDP/abs/html/here-docs.html
# Some common things I ignore.
cat >> .gitignore <<customIgnoreExpressions
# Begin custom ignore expressions
backup/
${APPLICATION_DIRECTORY}/bin/phpunit
${APPLICATION_DIRECTORY}/phpunit.xml.dist
${APPLICATION_DIRECTORY}/public/apple-touch-icon.png
${APPLICATION_DIRECTORY}/public/build/
${APPLICATION_DIRECTORY}/public/favicon.ico
${APPLICATION_DIRECTORY}/public/images/brand-96\.png
${APPLICATION_DIRECTORY}/public/images/brand\.png
${APPLICATION_DIRECTORY}/public/images/logo\.svg
${APPLICATION_DIRECTORY}/public/uploads/
# End custom ignore expressions
customIgnoreExpressions

composer init --no-interaction \
    --name "$VENDOR/$PROJECT_NAME-bin" \
    --description "$PROJECT_DESCRIPTION" \
    --author "$YOUR_NAME <$YOUR_EMAIL>" \
    --type project \
    --license "$PROJECT_LICENSE" \
    --require-dev "dealerdirect/phpcodesniffer-composer-installer:0.4.*" \
    --require-dev "deployer/deployer:6.*" \
    --require-dev "deployer/recipes:6.*" \
    --require-dev "escapestudios/symfony2-coding-standard:3.*" \
    --require-dev "squizlabs/php_codesniffer:3.*"
composer install

cat > deployer.php <<DEPLOYER_PHP
<?php
namespace Deployer;

require 'vendor/autoload.php';

require 'recipe/symfony3.php';
require 'recipe/rsync.php';

// Project name
set('application', '${PROJECT_NAME}');

// Project repository
set('repository', '${GIT_REPOSITORY}');

// [Optional] Allocate tty for git clone. Default value is false.
set('git_tty', true);

// Shared files/dirs between deploys
add('shared_files', array('.env'));
set('shared_dirs', array(
    'var/log',
    'var/sessions',
));

// Writable dirs by web server
set('writable_dirs', array('var/cache', 'var/log', 'var/sessions'));

// deploy.php

// Symfony web dir
set('web_dir', 'public');

// Assets
set('assets', array('public/css', 'public/images', 'public/js'));

set('rsync', array(
    'exclude'       => array(),
    //Use absolute path to avoid possible rsync problems
    'exclude-file'  => __DIR__.'/rsync-exclude.txt',
    'include'       => array(),
    'include-file'  => false,
    'filter'        => array(),
    'filter-file'   => false,
    'filter-perdir' => false,
    // arsync with deployer specific stuff
    'flags'         => 'rlshPizcE',
    //Delete after successful transfer, delete even if deleted dir is not empty
    'options'       => array('delete', 'delete-after', 'force'),
    //for those huge repos or crappy connection
    'timeout'       => 3600,
));

// Hosts
host('${DEPLOYMENT_HOSTNAME}')
    ->user('${DEPLOYMENT_USERNAME}')
    // If your username is john, then ${APPLICATION_DIRECTORY} will be synced to /home/john/{{application}}/
    ->set('deploy_path', '${DEPLOYMENT_DIRECTORY}')
    ->set('rsync_src', '${APPLICATION_DIRECTORY}')
    ->set('rsync_dest', '{{release_path}}');

task('deploy:writable', function () {
    cd('{{release_path}}');
    run('find "{{release_path}}" -type d -not -wholename "{{release_path}}" -exec chmod 755 \'{}\' \;');
    run('find "{{release_path}}" -type f -exec chmod 644 \'{}\' \;');
    run('chmod 755 bin/*');
    run('chmod 755 vendor/bin/*');
});

task('deploy', array(
    'deploy:info',
    'deploy:prepare',
    'deploy:lock',
    'deploy:release',
    'rsync',
    'deploy:clear_paths',
    'deploy:create_cache_dir',
    'deploy:shared',
    'deploy:vendors',
    'deploy:cache:clear',
    'deploy:cache:warmup',
    'deploy:writable',
    'deploy:symlink',
    'deploy:unlock',
    'cleanup',
))->desc('Deploy your project');

// [Optional] if deploy fails automatically unlock.
after('deploy:failed', 'deploy:unlock');

// Migrate database before symlink new release.
before('deploy:symlink', 'database:migrate');
DEPLOYER_PHP

cat > Makefile <<MAKEFILE
# when you run 'make' alone, run the 'css' rule (at the
# bottom of this makefile)
all: build.dev

# .PHONY is a special command, that allows you not to
# require physical files as the target (allowing us to
# use the 'all' rule as the default target).
.PHONY: all

NO_CLEAN_DEV_ARGS=-e \!${APPLICATION_DIRECTORY}/.web-server-pid -e \!${APPLICATION_DIRECTORY}/bin/phpunit -e \!${APPLICATION_DIRECTORY}/phpunit.xml.dist -e \!${APPLICATION_DIRECTORY}/src/DataFixtures/.gitignore -e \!${APPLICATION_DIRECTORY}/tests/.gitignore -e \!${APPLICATION_DIRECTORY}/.gitignore

# Begin Cleaning Targets
clean: clean.app-res
	git clean -Xdf \$(NO_CLEAN_DEV_ARGS) -e \!backup --exclude \!/${APPLICATION_DIRECTORY}/node_modules/ --exclude \!/${APPLICATION_DIRECTORY}/node_modules/** -e \!${APPLICATION_DIRECTORY}/vendor -e \!vendor -e \!${APPLICATION_DIRECTORY}/.env

clean-dev: clean
	git clean -Xdf \$(NO_CLEAN_DEV_ARGS) -e \!${APPLICATION_DIRECTORY}/.env -e \!backup

clean.app-res:
	make -C app-res/ clean

clean.cache:
	git clean -Xdf ${APPLICATION_DIRECTORY}/var/cache/ ${APPLICATION_DIRECTORY}/var/sessions/

clean.vendor:
	rm -rf ${APPLICATION_DIRECTORY}/vendor/
	rm -rf vendor/
# End Cleaning Targets

# Begin Deploy Targets
deploy: clean composer.deploy build.prod
	vendor/bin/dep -vv deploy
# End Deploy Targets

# Begin Doctrine Targets
schema.validate.prod:
	ssh ${DEPLOYMENT_USERNAME}@${DEPLOYMENT_HOSTNAME} ${DEPLOYMENT_DIRECTORY}/current/bin/console doctrine:schema:validate

schema.validate.dev:
	${APPLICATION_DIRECTORY}/bin/console doctrine:schema:validate

schema.create.dev:
	${APPLICATION_DIRECTORY}/bin/console doctrine:schema:create
# End Doctrine Targets

# Begin Compile Targets
build.dev: composer.dev prepare icons images
	cd ${APPLICATION_DIRECTORY}/ && yarn run encore dev

build.prod: composer.dev prepare icons images
	cd ${APPLICATION_DIRECTORY}/ && yarn run encore production

branding: app-res/Makefile
	make -C app-res

icons: ${APPLICATION_DIRECTORY}/public/apple-touch-icon.png ${APPLICATION_DIRECTORY}/public/favicon.ico

${APPLICATION_DIRECTORY}/public/images/:
	mkdir -p ${APPLICATION_DIRECTORY}/public/images/

images: ${APPLICATION_DIRECTORY}/public/images/ ${APPLICATION_DIRECTORY}/public/images/logo.svg ${APPLICATION_DIRECTORY}/public/images/brand.png ${APPLICATION_DIRECTORY}/public/images/brand-96.png

${APPLICATION_DIRECTORY}/public/apple-touch-icon.png: branding
	cp app-res/dist/favicon/favicon-120.png ${APPLICATION_DIRECTORY}/public/apple-touch-icon.png

${APPLICATION_DIRECTORY}/public/favicon.ico: branding
	cp app-res/dist/favicon/favicon.ico ${APPLICATION_DIRECTORY}/public/favicon.ico

${APPLICATION_DIRECTORY}/public/images/logo.svg: branding
	cp app-res/assets/Heartland.svg ${APPLICATION_DIRECTORY}/public/images/logo.svg

${APPLICATION_DIRECTORY}/public/images/brand.png:
	rsvg-convert --width 30 --height 30 --keep-aspect-ratio --output ${APPLICATION_DIRECTORY}/public/images/brand.png --format png app-res/assets/Heartland.svg

${APPLICATION_DIRECTORY}/public/images/brand-96.png:
	rsvg-convert --width 96 --height 96 --keep-aspect-ratio --output ${APPLICATION_DIRECTORY}/public/images/brand-96.png --format png app-res/assets/Heartland.svg
# End Compile Targets

# Begin Test Targets
phpcs: phpcs.errors

phpcbf: phpcbf.errors

phpcs.warnings: composer.deploy
	vendor/bin/phpcs -p --colors --standard=phpcs.xml ${APPLICATION_DIRECTORY}/src/
	vendor/bin/phpcs -p --colors --standard=phpcs.xml deploy.php

phpcbf.warnings: composer.deploy
	vendor/bin/phpcbf -p --colors --standard=phpcs.xml ${APPLICATION_DIRECTORY}/src/
	vendor/bin/phpcbf -p --colors --standard=phpcs.xml deploy.php

phpcs.errors: composer.deploy
	vendor/bin/phpcs -p --colors --warning-severity=0 --standard=phpcs.xml ${APPLICATION_DIRECTORY}/src/
	vendor/bin/phpcs -p --colors --warning-severity=0 --standard=phpcs.xml deploy.php

phpcbf.errors: composer.deploy
	vendor/bin/phpcbf -p --colors --warning-severity=0 --standard=phpcs.xml ${APPLICATION_DIRECTORY}/src/
	vendor/bin/phpcbf -p --colors --warning-severity=0 --standard=phpcs.xml deploy.php

fixtures:
	${APPLICATION_DIRECTORY}/bin/console doctrine:fixtures:load --no-interaction

phpunit:
	cd ${APPLICATION_DIRECTORY}/ && bin/phpunit tests/
# End Test Targets

# Begin Prepare Targets
app-res/Makefile:
	git submodule init
	git submodule update

prepare: ${APPLICATION_DIRECTORY}/node_modules/

composer.deploy:
	composer install

composer.dev:
	cd ${APPLICATION_DIRECTORY}/ && composer install

${APPLICATION_DIRECTORY}/node_modules/: ${APPLICATION_DIRECTORY}/package.json ${APPLICATION_DIRECTORY}/yarn.lock
	cd ${APPLICATION_DIRECTORY}/ && yarn install
	touch ${APPLICATION_DIRECTORY}/node_modules/
# End Prepare Targets

# Begin Docker Targets
docker.up:
	cd services/mysql/ && docker-compose up -d

docker.down:
	cd services/mysql/ && docker-compose down

docker.destroy:
	cd services/mysql/ && docker-compose down --volumes
# End Docker Targets

# Begin Server Targets
server.up:
	cd ${APPLICATION_DIRECTORY}/ && bin/console server:start 0.0.0.0:8000

server.down:
	cd ${APPLICATION_DIRECTORY}/ && bin/console server:stop
# End Server Targets
MAKEFILE

cat > phpcs.xml <<PHPCS_XML
<?xml version="1.0"?>
<ruleset name="${PROJECT_NAME}">
  <description>${PROJECT_DESCRIPTION}</description>

  <rule ref="PSR1">
    <exclude name="PSR1.Methods.CamelCapsMethodName.NotCamelCaps" />
    <exclude name="Generic.Files.LineLength.TooLong" />
  </rule>
  <rule ref="PSR2" />

  <rule ref="Generic.PHP.DeprecatedFunctions"/>
  <rule ref="Generic.PHP.ForbiddenFunctions"/>
  <rule ref="Generic.Functions.CallTimePassByReference"/>
  <rule ref="Generic.Formatting.DisallowMultipleStatements"/>
  <rule ref="Generic.CodeAnalysis.EmptyStatement" />
  <rule ref="Generic.CodeAnalysis.ForLoopShouldBeWhileLoop"/>
  <rule ref="Generic.CodeAnalysis.ForLoopWithTestFunctionCall"/>
  <rule ref="Generic.CodeAnalysis.JumbledIncrementer"/>
  <rule ref="Generic.CodeAnalysis.UnconditionalIfStatement"/>
  <rule ref="Generic.CodeAnalysis.UnnecessaryFinalModifier"/>
  <rule ref="Generic.CodeAnalysis.UselessOverridingMethod"/>
  <rule ref="Generic.Classes.DuplicateClassName"/>
  <rule ref="Generic.Strings.UnnecessaryStringConcat"/>

  <rule ref="Symfony" />

  <rule ref="Generic.Arrays.DisallowShortArraySyntax" />
</ruleset>

PHPCS_XML
