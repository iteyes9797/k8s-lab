# 1. 로드밸런서용 공인 IP
resource "azurerm_public_ip" "lb_pip" {
  name                = "pip-k8s-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 2. 로드밸런서 본체
resource "azurerm_lb" "main" {
  name                = "lb-k8s-service"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

# 3. 백엔드 풀 (워커 노드들이 담길 바구니)
resource "azurerm_lb_backend_address_pool" "pool" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "K8sWorkerPool"
}

# 4. 상태 검사 (30080 포트가 살아있는지 확인)
resource "azurerm_lb_probe" "hp" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "http-nodeport-probe"
  port            = 30080
  protocol        = "Tcp"
}

# 5. LB 규칙 (80으로 들어오면 30080으로 전달)
resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "LBRule-HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 30080
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
  probe_id                       = azurerm_lb_probe.hp.id
}