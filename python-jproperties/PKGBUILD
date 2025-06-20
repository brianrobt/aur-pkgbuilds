# Maintainer: Brian Thompson <brianrobt@pm.me>
# Contributor: Yacob Zitouni <yacob.zitouni@gmail.com>

pkgname=python-jproperties
_name=jproperties
pkgver=2.1.2
pkgrel=1
pkgdesc='Java Property file parser and writer for Python'
url='https://github.com/Tblue/python-jproperties'
depends=(
    'python3'
    'python-importlib-metadata'
    'python-setuptools'
    'python-six')
makedepends=(
    'python-setuptools'
    'python-setuptools-scm'
    'python-pytest')
license=('PSF-2.0')
arch=('any')
source=("https://files.pythonhosted.org/packages/source/${_name::1}/$_name/$_name-$pkgver.tar.gz"
        'setuptools_scm-version.patch')
sha256sums=('036fcd52c10a8a1c21e6fa2a1c292c93892e759b76490acc4809213a36ddc329'
            '5248a60a7943670fdb0b3159e233a2a7912f040a563d148bab5bb1175668b757')

prepare() {
    cd "$srcdir"
    patch  --forward --strip=1 --input="$srcdir/setuptools_scm-version.patch"  # Fix issue https://github.com/Tblue/python-jproperties/issues/15
}

build() {
    cd "$srcdir/$_name-$pkgver"
    python setup.py build
}

package() {
    cd "$srcdir/$_name-$pkgver"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    python setup.py install --root="$pkgdir" --optimize=1
}
