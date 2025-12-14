#!/bin/bash

[[ $EUID -ne 0 ]] && echo "Ejecuta como root" && exit 1

SERVICE_DIR="/etc/systemd/system"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # Sin color

# Caracteres gráficos
CHECK="✓"
CROSS="✗"
ARROW="→"
BULLET="●"

pause() {
  echo ""
  read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${NC}")"
}

print_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${WHITE}          PORT MIRRORING MANAGER v2.0               ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_section() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${WHITE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

get_ifaces() {
  ifconfig -a | awk '/^[a-zA-Z0-9]/ {print $1}' | sed 's/:$//'
}

iface_status() {
  if ifconfig "$1" 2>/dev/null | grep -q "UP"; then
    echo -e "${GREEN}UP${NC}"
  else
    echo -e "${RED}DOWN${NC}"
  fi
}

iface_status_raw() {
  if ifconfig "$1" 2>/dev/null | grep -q "UP"; then
    echo "UP"
  else
    echo "DOWN"
  fi
}

select_iface() {
  local prompt="$1"
  local ifaces
  mapfile -t ifaces < <(get_ifaces)

  echo -e "${YELLOW}$prompt${NC}" >&2
  echo ""

  local i=1
  for iface in "${ifaces[@]}"; do
    local status=$(iface_status "$iface")
    echo -e "  ${CYAN}$i)${NC} $iface ${GRAY}[${NC}$status${GRAY}]${NC}" >&2
    ((i++))
  done
  echo ""

  while true; do
    read -rp "$(echo -e "${WHITE}Seleccione número: ${NC}")" selection >&2
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#ifaces[@]}" ]; then
      echo "${ifaces[$((selection-1))]}"
      return
    else
      echo -e "${RED}Selección inválida${NC}" >&2
    fi
  done
}

show_tc() {
  local IF="$1"
  echo -e "${CYAN}Qdisc:${NC}"
  tc qdisc show dev "$IF"
  echo -e "${CYAN}Ingress:${NC}"
  tc filter show dev "$IF" ingress
  echo -e "${CYAN}Egress:${NC}"
  tc filter show dev "$IF" egress
}

# Función mejorada para mostrar estadísticas de tráfico
show_traffic_stats() {
  local IF="$1"
  local RX_PACKETS=$(ifconfig "$IF" 2>/dev/null | awk '/RX packets/ {print $3}')
  local TX_PACKETS=$(ifconfig "$IF" 2>/dev/null | awk '/TX packets/ {print $3}')
  local RX_BYTES=$(ifconfig "$IF" 2>/dev/null | awk '/RX packets/ {print $5}' | sed 's/[()]//g')
  local TX_BYTES=$(ifconfig "$IF" 2>/dev/null | awk '/TX packets/ {print $5}' | sed 's/[()]//g')

  echo -e "  ${GRAY}RX:${NC} $RX_PACKETS pkts ($RX_BYTES) ${GRAY}|${NC} ${GRAY}TX:${NC} $TX_PACKETS pkts ($TX_BYTES)"
}

show_active_mirroring() {
  print_header
  print_section "PORT MIRRORING ACTIVOS"

  local found=0
  local count=1

  for SRC_IF in $(get_ifaces); do
    if tc qdisc show dev "$SRC_IF" 2>/dev/null | grep -q "clsact"; then

      local INGRESS=$(tc filter show dev "$SRC_IF" ingress 2>/dev/null | grep "mirred")
      local EGRESS=$(tc filter show dev "$SRC_IF" egress 2>/dev/null | grep "mirred")

      if [[ -n "$INGRESS" ]] || [[ -n "$EGRESS" ]]; then
        found=1

        local DST_IF=""
        local TRAFFIC_TYPE=""
        local TRAFFIC_COLOR=""

        if [[ -n "$INGRESS" ]]; then
          DST_IF=$(echo "$INGRESS" | sed -n 's/.*mirred.*dev \([^ ]*\).*/\1/p' | head -1)
          if [[ -n "$EGRESS" ]]; then
            TRAFFIC_TYPE="RX + TX"
            TRAFFIC_COLOR="${MAGENTA}"
          else
            TRAFFIC_TYPE="RX (Ingress)"
            TRAFFIC_COLOR="${GREEN}"
          fi
        elif [[ -n "$EGRESS" ]]; then
          DST_IF=$(echo "$EGRESS" | sed -n 's/.*mirred.*dev \([^ ]*\).*/\1/p' | head -1)
          TRAFFIC_TYPE="TX (Egress)"
          TRAFFIC_COLOR="${YELLOW}"
        fi

        echo -e "${CYAN}╭─────────────────────────────────────────────────────────╮${NC}"
        echo -e "${CYAN}│${NC} ${WHITE}Mirror #$count${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC} ${CYAN}SOURCE:${NC}      $SRC_IF $(iface_status "$SRC_IF")"
        show_traffic_stats "$SRC_IF"
        echo -e "${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}        ${BLUE}${ARROW}${NC} ${TRAFFIC_COLOR}${TRAFFIC_TYPE}${NC}"
        echo -e "${CYAN}│${NC}"
        echo -e "${CYAN}│${NC} ${CYAN}DESTINATION:${NC} $DST_IF $(iface_status "$DST_IF")"
        show_traffic_stats "$DST_IF"

        local SERVICE="port-mirroring-${SRC_IF}.service"
        if [[ -f "${SERVICE_DIR}/${SERVICE}" ]]; then
          local STATUS=$(systemctl is-enabled "$SERVICE" 2>/dev/null)
          local ACTIVE=$(systemctl is-active "$SERVICE" 2>/dev/null)
          if [[ "$ACTIVE" == "active" ]]; then
            echo -e "${CYAN}│${NC} ${GREEN}${CHECK}${NC} ${WHITE}Persistente${NC} ${GRAY}(systemd: ${STATUS})${NC}"
          else
            echo -e "${CYAN}│${NC} ${YELLOW}${CHECK}${NC} ${WHITE}Persistente${NC} ${GRAY}(systemd: ${STATUS}, inactivo)${NC}"
          fi
        else
          echo -e "${CYAN}│${NC} ${RED}${CROSS}${NC} ${GRAY}No persistente (solo en memoria)${NC}"
        fi

        echo -e "${CYAN}╰─────────────────────────────────────────────────────────╯${NC}"
        echo ""
        ((count++))
      fi
    fi
  done

  if [[ $found -eq 0 ]]; then
    echo -e "${GRAY}No hay port-mirroring activos en el sistema.${NC}"
    echo ""
  else
    echo -e "${GREEN}${BULLET}${NC} Total: $((count-1)) mirror(s) activo(s)"
    echo ""
  fi

  print_section "SERVICIOS SYSTEMD"

  local systemd_found=0
  for SERVICE_FILE in "${SERVICE_DIR}"/port-mirroring-*.service; do
    if [[ -f "$SERVICE_FILE" ]]; then
      systemd_found=1
      local SERVICE_NAME=$(basename "$SERVICE_FILE")
      local SRC_IF=$(echo "$SERVICE_NAME" | sed 's/port-mirroring-\(.*\)\.service/\1/')
      local STATUS=$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null)
      local ACTIVE=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null)

      if [[ "$ACTIVE" == "active" ]]; then
        echo -e "  ${GREEN}${BULLET}${NC} $SERVICE_NAME"
      else
        echo -e "  ${YELLOW}${BULLET}${NC} $SERVICE_NAME"
      fi
      echo -e "    ${GRAY}└─${NC} Interfaz: ${CYAN}$SRC_IF${NC} ${GRAY}|${NC} Estado: ${WHITE}$STATUS${NC} ${GRAY}|${NC} Activo: ${WHITE}$ACTIVE${NC}"
    fi
  done

  if [[ $systemd_found -eq 0 ]]; then
    echo -e "${GRAY}No hay servicios systemd configurados.${NC}"
  fi

  pause
}

create_systemd_service() {
  local SRC="$1"
  local DST="$2"
  local MODE="$3"

  local SERVICE="port-mirroring-${SRC}.service"

  cat > "${SERVICE_DIR}/${SERVICE}" <<EOF
[Unit]
Description=Port Mirroring ${SRC} -> ${DST}
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/tc qdisc add dev ${SRC} clsact
EOF

  [[ "$MODE" == "RX" || "$MODE" == "BOTH" ]] && \
    echo "ExecStart=/sbin/tc filter add dev ${SRC} ingress matchall action mirred egress mirror dev ${DST}" >> "${SERVICE_DIR}/${SERVICE}"

  [[ "$MODE" == "TX" || "$MODE" == "BOTH" ]] && \
    echo "ExecStart=/sbin/tc filter add dev ${SRC} egress matchall action mirred egress mirror dev ${DST}" >> "${SERVICE_DIR}/${SERVICE}"

  cat >> "${SERVICE_DIR}/${SERVICE}" <<EOF

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$SERVICE"
  echo -e "${GREEN}${CHECK}${NC} Servicio systemd creado y habilitado"
}

remove_systemd_service() {
  local SRC="$1"
  local SERVICE="port-mirroring-${SRC}.service"

  if [[ -f "${SERVICE_DIR}/${SERVICE}" ]]; then
    systemctl disable --now "$SERVICE"
    rm -f "${SERVICE_DIR}/${SERVICE}"
    systemctl daemon-reload
    echo -e "${GREEN}${CHECK}${NC} Servicio systemd eliminado"
  else
    echo -e "${YELLOW}No se encontró servicio systemd para esta interfaz${NC}"
  fi
}

add_mirroring() {
  print_header
  print_section "CREAR PORT MIRRORING"

  SRC=$(select_iface "Selecciona interfaz SOURCE (origen del tráfico):")
  SRC=$(echo "$SRC" | tr -d '\n\r')
  echo ""
  DST=$(select_iface "Selecciona interfaz DESTINATION (destino del mirror):")
  DST=$(echo "$DST" | tr -d '\n\r')

  if [[ "$SRC" == "$DST" ]]; then
    echo ""
    echo -e "${RED}${CROSS} Error: Las interfaces no pueden ser iguales${NC}"
    pause
    return
  fi

  echo ""
  echo -e "${YELLOW}Tipo de tráfico a monitorear:${NC}"
  echo -e "  ${CYAN}1)${NC} RX  ${GRAY}(solo tráfico entrante)${NC}"
  echo -e "  ${CYAN}2)${NC} TX  ${GRAY}(solo tráfico saliente)${NC}"
  echo -e "  ${CYAN}3)${NC} RX + TX  ${GRAY}(bidireccional)${NC}"
  echo ""
  read -rp "$(echo -e "${WHITE}Opción: ${NC}")" MODE

  tc qdisc add dev "$SRC" clsact 2>/dev/null

  case "$MODE" in
    1)
      tc filter add dev "$SRC" ingress matchall action mirred egress mirror dev "$DST"
      MODE_NAME="RX"
      echo -e "${GREEN}${CHECK}${NC} Mirror RX configurado: $SRC ${ARROW} $DST"
      ;;
    2)
      tc filter add dev "$SRC" egress matchall action mirred egress mirror dev "$DST"
      MODE_NAME="TX"
      echo -e "${GREEN}${CHECK}${NC} Mirror TX configurado: $SRC ${ARROW} $DST"
      ;;
    3)
      tc filter add dev "$SRC" ingress matchall action mirred egress mirror dev "$DST"
      tc filter add dev "$SRC" egress matchall action mirred egress mirror dev "$DST"
      MODE_NAME="BOTH"
      echo -e "${GREEN}${CHECK}${NC} Mirror RX+TX configurado: $SRC ${ARROW} $DST"
      ;;
    *)
      echo -e "${RED}${CROSS} Opción inválida${NC}"
      pause
      return
      ;;
  esac

  echo ""
  read -rp "$(echo -e "${YELLOW}¿Hacer persistente con systemd? (s/n): ${NC}")" PERSIST
  if [[ "$PERSIST" == "s" ]]; then
    create_systemd_service "$SRC" "$DST" "$MODE_NAME"
  fi

  pause
}

remove_mirroring() {
  print_header
  print_section "ELIMINAR PORT MIRRORING"

  IFACE=$(select_iface "Selecciona la interfaz:")
  IFACE=$(echo "$IFACE" | tr -d '\n\r')

  echo ""
  echo -e "${CYAN}Configuración actual en $IFACE:${NC}"
  echo ""
  show_tc "$IFACE"

  echo ""
  read -rp "$(echo -e "${RED}¿Confirmar eliminación? (s/n): ${NC}")" CONF
  if [[ "$CONF" != "s" ]]; then
    echo -e "${YELLOW}Operación cancelada${NC}"
    pause
    return
  fi

  tc filter del dev "$IFACE" ingress 2>/dev/null
  tc filter del dev "$IFACE" egress 2>/dev/null
  tc qdisc del dev "$IFACE" clsact 2>/dev/null

  echo -e "${GREEN}${CHECK}${NC} Port mirroring eliminado"

  echo ""
  read -rp "$(echo -e "${YELLOW}¿Eliminar persistencia systemd? (s/n): ${NC}")" DEL
  if [[ "$DEL" == "s" ]]; then
    remove_systemd_service "$IFACE"
  fi

  pause
}

show_status_all() {
  print_header
  print_section "ESTADO TÉCNICO (TC) - TODAS LAS INTERFACES"

  for IF in $(get_ifaces); do
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} Interfaz: ${WHITE}$IF${NC} $(iface_status "$IF")"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    show_tc "$IF"
    echo ""
  done
  pause
}

# ===== MENU PRINCIPAL =====
while true; do
  print_header

  # Contador rápido de mirrors activos
  active_count=0
  for SRC_IF in $(get_ifaces); do
    if tc qdisc show dev "$SRC_IF" 2>/dev/null | grep -q "clsact"; then
      INGRESS=$(tc filter show dev "$SRC_IF" ingress 2>/dev/null | grep "mirred")
      EGRESS=$(tc filter show dev "$SRC_IF" egress 2>/dev/null | grep "mirred")
      [[ -n "$INGRESS" || -n "$EGRESS" ]] && ((active_count++))
    fi
  done

  if [[ $active_count -gt 0 ]]; then
    echo -e "${GREEN}${BULLET}${NC} ${WHITE}Mirrors activos: ${GREEN}$active_count${NC}"
  else
    echo -e "${GRAY}${BULLET} Sin mirrors activos${NC}"
  fi

  echo ""
  echo -e "${CYAN}┌────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC}  ${CYAN}1)${NC} ${WHITE}Crear port mirroring${NC}                          ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${CYAN}2)${NC} ${WHITE}Ver port-mirroring activos${NC}                    ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${CYAN}3)${NC} ${WHITE}Ver estado técnico (tc)${NC}                       ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${CYAN}4)${NC} ${WHITE}Eliminar port mirroring${NC}                       ${CYAN}│${NC}"
  echo -e "${CYAN}│${NC}  ${CYAN}5)${NC} ${RED}Salir${NC}                                         ${CYAN}│${NC}"
  echo -e "${CYAN}└────────────────────────────────────────────────────────┘${NC}"
  echo ""
  read -rp "$(echo -e "${WHITE}Seleccione una opción: ${NC}")" OPT

  case "$OPT" in
    1) add_mirroring ;;
    2) show_active_mirroring ;;
    3) show_status_all ;;
    4) remove_mirroring ;;
    5)
      clear
      echo -e "${GREEN}¡Hasta luego!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Opción inválida${NC}"
      sleep 1
      ;;
  esac
done
