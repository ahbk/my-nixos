import socket

import ping3
import requests


def test_esse_nu():
    url = "http://esse.nu"
    response = requests.get(url)
    assert (
        response.status_code == 200
    ), f"Expected status 200, but got {response.status_code}"


def test_sverigesval_org():
    url = "http://sverigesval.org"
    response = requests.get(url)
    assert (
        response.status_code == 200
    ), f"Expected status 200, but got {response.status_code}"


def test_chatddx_com():
    url = "http://chatddx.com"
    response = requests.get(url)
    assert (
        response.status_code == 200
    ), f"Expected status 200, but got {response.status_code}"


def test_sysctl():
    url = "http://sysctl-user-portal.curetheweb.se"
    response = requests.get(url)
    assert (
        response.status_code == 200
    ), f"Expected status 200, but got {response.status_code}"


def test_ping_10_0_0_1():
    response_time = ping3.ping("10.0.0.1")
    assert response_time is not None, "Ping failed, no response from 10.0.0.1"


def test_ping_10_0_0_2():
    response_time = ping3.ping("10.0.0.2")
    assert response_time is not None, "Ping failed, no response from 10.0.0.2"


def test_ping_10_0_0_3():
    response_time = ping3.ping("10.0.0.3")
    assert response_time is not None, "Ping failed, no response from 10.0.0.3"


def test_dns_stationary_ahbk():
    expected_ip = "10.0.0.1"
    try:
        resolved_ip = socket.gethostbyname("stationary.ahbk")
        assert (
            resolved_ip == expected_ip
        ), f"Expected {expected_ip}, but got {resolved_ip}"
    except socket.gaierror:
        assert False, "DNS resolution failed for stationary.ahbk"


def test_dns_glesys_ahbk():
    expected_ip = "10.0.0.3"
    try:
        resolved_ip = socket.gethostbyname("glesys.ahbk")
        assert (
            resolved_ip == expected_ip
        ), f"Expected {expected_ip}, but got {resolved_ip}"
    except socket.gaierror:
        assert False, "DNS resolution failed for glesys.ahbk"
