# Maintainer: Brian Thompson <brianrobt@pm.me>
# Contributor: envolution

pkgname=python-hunspell
_name=pyhunspell
pkgver=0.5.5
pkgrel=1
pkgdesc='Python bindings for the Hunspell spellchecker engine'
arch=('x86_64')
url='https://github.com/pyhunspell/pyhunspell'
license=('GPL-3.0-only')
depends=(
	'gcc-libs'
	'glibc'
	'hunspell')
makedepends=(
	'python-build'
	'python-installer'
	'python-setuptools'
	'python-wheel')
source=("$_name-$pkgver.tar.gz::$url/archive/refs/tags/$pkgver.tar.gz")
sha256sums=('021f2b713ebf1af972655b7f7a7669e96d8e2c59f4c984164b3fc1b7b5e2a51c')
provides=('python-hunspell')

build() {
	cd "$_name-$pkgver" || exit
	python -m build --wheel --no-isolation
}

package() {
	cd "$_name-$pkgver" || exit
	python -m installer --destdir="$pkgdir/" dist/*.whl
}
