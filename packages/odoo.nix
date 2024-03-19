{ stdenv
, lib
, fetchzip
, python311
, nixosTests
}:

let
  python = python311.override {
    packageOverrides = self: super: {
      flask = super.flask.overridePythonAttrs (old: rec {
        version = "2.3.3";
        src = old.src.override {
          inherit version;
          hash = "sha256-CcNHqSqn/0qOfzIGeV8w2CZlS684uHPQdEzVccpgnvw=";
        };
      });
      werkzeug = super.werkzeug.overridePythonAttrs (old: rec {
        version = "2.3.7";
        src = old.src.override {
          inherit version;
          hash = "sha256-K4wORHtLnbzIXdl7butNy69si2w74L1lTiVVPgohV9g=";
        };
      });
    };
  };

  odoo_version = "17.0";
  odoo_release = "20240312";
in python.pkgs.buildPythonApplication rec {
  pname = "odoo";
  version = "${odoo_version}.${odoo_release}";

  format = "setuptools";

  # latest release is at https://github.com/odoo/docker/blob/master/17.0/Dockerfile
  src = fetchzip {
    url = "https://nightly.odoo.com/${odoo_version}/nightly/src/odoo_${version}.zip";
    name = "${pname}-${version}";
    hash = "sha256-iPLKOABZcwnGYUXWN9Az8Q6S2t3A0JmVxAYUrAvcvek="; # odoo
  };

  # needs some investigation
  doCheck = false;

  propagatedBuildInputs = with python.pkgs; [
    babel
    chardet
    cryptography
    decorator
    docutils
    ebaysdk
    freezegun
    geoip2
    gevent
    greenlet
    idna
    jinja2
    libsass
    lxml
    markupsafe
    num2words
    ofxparse
    passlib
    pillow
    polib
    psutil
    psycopg2
    pydot
    pyopenssl
    pypdf2
    pyserial
    python-dateutil
    python-ldap
    python-stdnum
    pytz
    pyusb
    qrcode
    reportlab
    requests
    rjsmin
    urllib3
    vobject
    werkzeug
    xlrd
    xlsxwriter
    xlwt
    zeep

    setuptools
    mock
  ];

  # takes 5+ minutes and there are not files to strip
  dontStrip = true;

  passthru = {
    updateScript = ./update.sh;
    tests = {
      inherit (nixosTests) odoo;
    };
  };

  meta = with lib; {
    description = "Open Source ERP and CRM";
    homepage = "https://www.odoo.com/";
    license = licenses.lgpl3Only;
    maintainers = with maintainers; [ mkg20001 ];
  };
}
