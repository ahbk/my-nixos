{ lib
, fetchzip
, python311
, rtlcss
, nixosTests
}:

let
  python = python311.override {
    packageOverrides = self: super: {
      werkzeug = super.werkzeug.overridePythonAttrs (old: rec {
        version = "2.3.8";
        src = old.src.override {
          inherit version;
          hash = "sha256-VUslfHS763oNJUFgpPj/4YUkP1KlIDUGC3Ycpi2XfwM=";
        };
      });
      pypdf2 = super.pypdf2.overridePythonAttrs (old: rec {
        version = "2.12.1";
        src = old.src.override {
          inherit version;
          hash = "sha256-4D7xirzHXadBoKzBp3SSU0loh744zZiHvM4c7jk9pF4=";
        };
      });
      flask = super.flask.overridePythonAttrs (old: rec {
        version = "2.3.3";
        src = old.src.override {
          inherit version;
          hash = "sha256-CcNHqSqn/0qOfzIGeV8w2CZlS684uHPQdEzVccpgnvw=";
        };
      });
    };
  };

  odoo_version = "17.0";
  odoo_release = "20240312";
  odoo_hash = "sha256-iPLKOABZcwnGYUXWN9Az8Q6S2t3A0JmVxAYUrAvcvek=";
in python.pkgs.buildPythonApplication rec {
  pname = "odoo";
  version = "${odoo_version}.${odoo_release}";

  format = "setuptools";

  # latest release is at https://github.com/odoo/docker/blob/master/17.0/Dockerfile
  # nightly at https://nightly.odoo.com/17.0/nightly/src
  src = fetchzip {
    url = "https://nightly.odoo.com/${odoo_version}/nightly/src/odoo_${version}.zip";
    name = "${pname}-${version}";
    hash = odoo_hash;
  };

  # needs some investigation
  doCheck = false;

  makeWrapperArgs = [
    "--prefix" "PATH" ":" "${lib.makeBinPath [ rtlcss ]}"
  ];

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

  # takes 5+ minutes and there are no files to strip
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
