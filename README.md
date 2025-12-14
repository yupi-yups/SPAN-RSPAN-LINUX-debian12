# Port Mirroring Manager v2.0

Una herramienta interactiva de línea de comandos para gestionar port mirroring (espejado de puertos) en Linux usando Traffic Control (tc).

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Bash](https://img.shields.io/badge/bash-5.0%2B-green.svg)
![Linux](https://img.shields.io/badge/platform-linux-lightgrey.svg)

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Requisitos](#-requisitos)
- [Instalación](#-instalación)
- [Uso](#-uso)
- [Funcionalidades](#-funcionalidades)
- [Ejemplos](#-ejemplos)
- [Navegación y Controles](#-navegación-y-controles)
- [Cómo Funciona](#-cómo-funciona)
- [Persistencia con systemd](#-persistencia-con-systemd)
- [Troubleshooting](#-troubleshooting)
- [Contribuir](#-contribuir)
- [Licencia](#-licencia)

## ✨ Características

- 🎨 **Interfaz colorida e intuitiva** con menús interactivos
- 🔄 **Port mirroring bidireccional** (RX, TX o ambos)
- 💾 **Persistencia con systemd** para mantener configuración tras reinicios
- 📊 **Visualización en tiempo real** de mirrors activos
- 📈 **Estadísticas de tráfico** (paquetes y bytes RX/TX)
- ⚙️ **Gestión completa** de configuraciones tc (Traffic Control)
- 🔍 **Vista técnica detallada** para debugging

## 🔧 Requisitos

### Sistema Operativo
- Linux con kernel 3.15+ (soporte para `tc` y `clsact`)
- Systemd (opcional, para persistencia)

### Interfaz
- La interfaz que se quiera utilizar como rspan o destination debe estar en modo `manual`
- Esto es similar al parametro `remote-span` que cisco usa para preparar la vlan. 
```bash
#Interfaz source#
auto eth0
iface eth0 inet dhcp

#Interfaz RSPAN#
auto eth1
iface eth1 inet manual
```
- Tambien puede usarse una interfaz vlan.
- Para crear una subinterfaz debe habilitarse el modulo 8021q de tal forma: `modprobe 8021q`
```bash
#Interfaz source#
auto eth0
iface eth0 inet dhcp

#Ejemplo Interfaz VLAN-RSPAN-1#
auto eth0.10
iface eth0.10 inet manual

#Ejemplo Interfaz VLAN-RSPAN-2#
auto eth1.10
iface eth1.10 inet manual
```
### Herramientas
```bash
# Debian/Ubuntu
apt-get install iproute2 net-tools

# RHEL/CentOS/Fedora
yum install iproute net-tools

# Arch Linux
pacman -S iproute2 net-tools
```

### Permisos
- Debe ejecutarse como **root** o con `sudo`

## 📥 Instalación

```bash
# Clonar el repositorio
https://github.com/yupi-yups/SPAN-RSPAN-LINUX-debian12.git
cd SPAN-RSPAN-LINUX-debian12

# Dar permisos de ejecución
chmod +x port-mirroring-manager.sh

# Ejecutar
sudo ./port-mirroring-manager.sh
```

## 🚀 Uso

### Inicio Rápido

```bash
sudo ./port-mirroring-manager.sh
```

### Menú Principal

```
╔════════════════════════════════════════════════════════╗
║          PORT MIRRORING MANAGER v2.0               ║
╚════════════════════════════════════════════════════════╝

● Mirrors activos: 2

┌────────────────────────────────────────────────────────┐
│  1) Crear port mirroring                          │
│  2) Ver port-mirroring activos                    │
│  3) Ver estado técnico (tc)                       │
│  4) Eliminar port mirroring                       │
│  0) ← Volver / Salir                              │
└────────────────────────────────────────────────────────┘
```

## 🎯 Funcionalidades

### 1. Crear Port Mirroring

Permite configurar el espejado de tráfico entre dos interfaces de red.

**Pasos:**
1. Seleccionar interfaz **SOURCE** (origen del tráfico)
2. Seleccionar interfaz **DESTINATION** (donde se copiará el tráfico)
3. Elegir tipo de tráfico:
   - **RX**: Solo tráfico entrante (ingress)
   - **TX**: Solo tráfico saliente (egress)
   - **RX + TX**: Tráfico bidireccional
4. Opcionalmente, hacer la configuración persistente con systemd

**💡 Navegación:**
- Presiona `0` en cualquier momento para **volver atrás**
- Si vuelves atrás después de configurar el mirror, los cambios se revierten automáticamente

**Casos de uso:**
- Monitoreo de tráfico con Wireshark
- IDS/IPS (Intrusion Detection/Prevention Systems)
- Análisis de red y troubleshooting
- Auditoría de seguridad

### 2. Ver Port-Mirroring Activos

Muestra todos los mirrors configurados actualmente con información detallada:

```
╭─────────────────────────────────────────────────────────╮
│ Mirror #1
├─────────────────────────────────────────────────────────┤
│ SOURCE:      eth0 UP
  RX: 15234 pkts (1.2GB) | TX: 8945 pkts (567MB)
│
│        → RX + TX
│
│ DESTINATION: eth1 UP
  RX: 892 pkts (45KB) | TX: 156 pkts (12KB)
│ ✓ Persistente (systemd: enabled)
╰─────────────────────────────────────────────────────────╯
```

**Información mostrada:**
- Interfaces SOURCE y DESTINATION con estado (UP/DOWN)
- Tipo de tráfico espejado
- Estadísticas en tiempo real
- Estado de persistencia systemd

### 3. Ver Estado Técnico (tc)

Muestra la configuración detallada de Traffic Control para todas las interfaces:
- Qdisc configurados
- Filtros ingress
- Filtros egress

Útil para debugging y verificación técnica.

### 4. Eliminar Port Mirroring

Permite remover configuraciones de mirroring existentes:
1. Selecciona la interfaz a limpiar
2. Muestra la configuración actual
3. Confirma la eliminación (o presiona `0` para cancelar)
4. Opcionalmente, elimina la persistencia systemd

**💡 Tip:** Usa `0` para cancelar en cualquier paso del proceso.

## 📚 Ejemplos

### Ejemplo 1: Monitorear tráfico de una interfaz WAN

```bash
# Espejear todo el tráfico de eth0 (WAN) a eth1 (donde está el sniffer)
1) Crear port mirroring
   SOURCE: eth0
   DESTINATION: eth1
   Tipo: RX + TX (bidireccional)
   Persistente: Sí
```

### Ejemplo 2: Análisis de tráfico saliente

```bash
# Solo capturar tráfico TX de una interfaz específica
1) Crear port mirroring
   SOURCE: ens3
   DESTINATION: ens4
   Tipo: TX (solo saliente)
   Persistente: No
```

### Ejemplo 3: IDS con múltiples interfaces

```bash
# Mirror 1: Tráfico WAN
SOURCE: eth0 → DESTINATION: eth2 (IDS)

# Mirror 2: Tráfico DMZ
SOURCE: eth1 → DESTINATION: eth2 (IDS)
```

## 🎮 Navegación y Controles

### Controles Universales

- **`0`** - Volver atrás en cualquier menú o selección
- **`1-9`** - Seleccionar opciones numéricas
- **`s/n`** - Confirmar o cancelar acciones
- **`ENTER`** - Continuar después de mensajes

### Flujo de Navegación

```
Menu Principal
    │
    ├─► [1] Crear Mirror
    │       ├─► Seleccionar SOURCE (0 = volver)
    │       ├─► Seleccionar DESTINATION (0 = volver)
    │       ├─► Tipo de tráfico (0 = volver)
    │       └─► Persistencia (0 = revertir cambios)
    │
    ├─► [2] Ver Activos
    │       └─► [ENTER para volver]
    │
    ├─► [3] Estado Técnico
    │       └─► [ENTER para volver]
    │
    ├─► [4] Eliminar Mirror
    │       ├─► Seleccionar interfaz (0 = volver)
    │       ├─► Confirmar (0 = cancelar)
    │       └─► Eliminar systemd (0 = omitir)
    │
    └─► [0] Salir
```

### Comportamiento Especial

**En "Crear Mirror":**
- Si presionas `0` después de configurar el mirror pero antes de confirmar la persistencia, **todos los cambios de tc se revierten automáticamente**
- Esto asegura que no queden configuraciones a medias

**En "Eliminar Mirror":**
- Presionar `0` en cualquier confirmación cancela toda la operación
- No se eliminará nada hasta que confirmes explícitamente con `s`

## ⚙️ Cómo Funciona

### Traffic Control (tc)

El script utiliza el subsistema **Traffic Control** del kernel Linux con la qdisc `clsact`:

```bash
# Agregar qdisc clsact a la interfaz
tc qdisc add dev eth0 clsact

# Agregar filtro para espejear tráfico ingress
tc filter add dev eth0 ingress matchall action mirred egress mirror dev eth1

# Agregar filtro para espejear tráfico egress
tc filter add dev eth0 egress matchall action mirred egress mirror dev eth1
```

### Componentes:

- **qdisc clsact**: Queue discipline que permite adjuntar filtros tanto en ingress como egress
- **matchall**: Coincide con todos los paquetes
- **mirred**: Mirror/redirect action que copia paquetes
- **mirror**: Copia el paquete sin modificar el original
- **egress**: Envía el paquete espejado a la interfaz de destino

### Flujo de Paquetes

```
┌─────────────┐
│   Paquete   │
│  entrante   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    eth0     │◄─── SOURCE
│  (ingress)  │
└──────┬──────┘
       │
       ├──────► [Procesamiento normal]
       │
       └──────► [COPIA] ────┐
                             │
                             ▼
                      ┌─────────────┐
                      │    eth1     │◄─── DESTINATION
                      │ (mirrored)  │
                      └─────────────┘
```

## 💾 Persistencia con systemd

Cuando se hace persistente, el script crea un servicio systemd:

**Archivo:** `/etc/systemd/system/port-mirroring-eth0.service`

```ini
[Unit]
Description=Port Mirroring eth0 -> eth1
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/tc qdisc add dev eth0 clsact
ExecStart=/sbin/tc filter add dev eth0 ingress matchall action mirred egress mirror dev eth1
ExecStart=/sbin/tc filter add dev eth0 egress matchall action mirred egress mirror dev eth1

[Install]
WantedBy=multi-user.target
```

### Gestión Manual

```bash
# Ver estado del servicio
systemctl status port-mirroring-eth0.service

# Iniciar manualmente
systemctl start port-mirroring-eth0.service

# Detener
systemctl stop port-mirroring-eth0.service

# Deshabilitar
systemctl disable port-mirroring-eth0.service
```

## 🔍 Troubleshooting

### Error: "Cannot find device"

**Causa:** La interfaz no existe o está mal escrita.

**Solución:**
```bash
# Listar interfaces disponibles
ip link show
# o
ifconfig -a
```

### El mirroring no funciona tras reinicio

**Causa:** No se configuró como persistente.

**Solución:**
1. Recrear el mirror
2. Responder "s" cuando pregunte por persistencia systemd

### Tráfico no se captura en la interfaz destino

**Verificaciones:**
```bash
# 1. Verificar que ambas interfaces están UP
ip link show

# 2. Verificar filtros tc
tc filter show dev eth0 ingress
tc filter show dev eth0 egress

# 3. Capturar tráfico en destino
tcpdump -i eth1 -n

# 4. Verificar que hay tráfico en origen
tcpdump -i eth0 -n
```

### Interfaz de destino muestra DOWN

**Causa:** La interfaz necesita estar administrativamente UP para recibir tráfico espejado.

**Solución:**
```bash
ip link set eth1 up
```

### Error: "RTNETLINK answers: File exists"

**Causa:** Ya existe una configuración clsact en la interfaz.

**Solución:**
```bash
# Eliminar configuración existente
tc qdisc del dev eth0 clsact

# Recrear el mirror
```

## 🐛 Debug

Para debugging detallado:

```bash
# Ver todos los qdisc
tc qdisc show

# Ver filtros de todas las interfaces
for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
    echo "=== $iface ==="
    tc filter show dev $iface ingress 2>/dev/null
    tc filter show dev $iface egress 2>/dev/null
done

# Ver logs de systemd
journalctl -u port-mirroring-*.service
```

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📝 Notas Importantes

- ⚠️ El port mirroring puede duplicar el tráfico y afectar el rendimiento en redes de alto throughput
- ⚠️ Asegúrate de que la interfaz de destino puede manejar el volumen de tráfico espejado
- ⚠️ No uses la misma interfaz como source y destination
- ⚠️ El tráfico espejado NO se modifica ni se elimina del flujo original
- 💡 Usa `0` para volver atrás en cualquier momento durante la configuración

## 👥 Autor

Desarrollado con ❤️ para la comunidad de administradores de sistemas Linux.

## 🔗 Enlaces Útiles

- [Linux Traffic Control HOWTO](https://tldp.org/HOWTO/Traffic-Control-HOWTO/)
- [tc man page](https://man7.org/linux/man-pages/man8/tc.8.html)
- [mirred action](https://man7.org/linux/man-pages/man8/tc-mirred.8.html)
- [clsact qdisc](https://man7.org/linux/man-pages/man8/tc-clsact.8.html)

---

**¿Preguntas o problemas?** Abre un issue en GitHub.
