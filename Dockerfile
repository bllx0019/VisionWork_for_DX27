# Utilisation de l'image officielle ROS Noetic
FROM osrf/ros:noetic-desktop-full

# Installation de quelques outils utiles + support GUI
RUN apt-get update && apt-get install -y \
    python3-rosdep \
    python3-rosinstall \
    python3-rosinstall-generator \
    python3-wstool \
    build-essential \
    nano \
    git \
    tmux \
    wget \
    curl \
    iputils-ping \
    net-tools \
    psmisc \
    # Librairies pour le support graphique
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    mesa-utils \
    x11-apps \
    # Outils ROS GUI
    ros-noetic-rqt \
    ros-noetic-rqt-common-plugins \
    ros-noetic-rviz \
    # ROS controllers
    ros-noetic-position-controllers \
    ros-noetic-effort-controllers \
    ros-noetic-joint-state-controller \
    # ROS simulator packages
    ros-noetic-husky-simulator \
    ros-noetic-husky-desktop \
    # smb_common_v2 (smb_control / smb_description / smb_gazebo) 依赖
    ros-noetic-hector-gazebo-plugins \
    ros-noetic-velodyne-description \
    ros-noetic-velodyne-gazebo-plugins \
    ros-noetic-twist-mux \
    ros-noetic-robot-localization \
    ros-noetic-teleop-twist-joy \
    ros-noetic-interactive-marker-twist-server \
    ros-noetic-joy \
    ros-noetic-joint-trajectory-controller \
    && rm -rf /var/lib/apt/lists/*

# rosdistro 走 BFSU 镜像：raw.githubusercontent.com / mirrors.tuna 在国内常被阻断或 403
ENV ROSDISTRO_INDEX_URL=https://mirrors.bfsu.edu.cn/rosdistro/index-v4.yaml

# Initialisation de rosdep (best-effort : un échec réseau ne bloque pas le build)
# Les dépendances concrètes sont installées ci-dessus via apt.
RUN rosdep init 2>/dev/null || true
RUN sed -i 's|raw.githubusercontent.com/ros/rosdistro/master|mirrors.bfsu.edu.cn/rosdistro|g' \
        /etc/ros/rosdep/sources.list.d/*.list \
    && rosdep update --include-eol-distros || echo "[warn] rosdep update ignoré (réseau)"

# Création d'un utilisateur non-root
ARG USERNAME=rosuser
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y \
        sudo \
        python3-catkin-tools \
        rsync \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*
# python3-catkin-tools：提供 catkin build（基础镜像只有 catkin_make）
# rsync：ros1.sh 用于工作区双向同步

# Passer à l'utilisateur non-root
USER $USERNAME
ENV HOME=/home/$USERNAME

# rosdep 缓存必须建在 rosuser 家目录下，否则运行时用不了（上面那次是 root 的）
# Noetic 已 EOL，rosdep 默认会跳过它的发布数据，必须加 --include-eol-distros
RUN rosdep update --include-eol-distros || echo "[warn] rosdep update (rosuser) ignoré (réseau)"

# 注意：不要在这里预建 $HOME/catkin_ws。
# 运行时 ros1.sh 会把宿主机工作区 bind mount 到 $HOME/catkin_ws，
# 镜像内的同名目录会被完全遮蔽；若在镜像里建它，反而会让人误以为容器内自带 devel。
RUN mkdir -p $HOME

# Configuration du shell pour charger ROS automatiquement
# 工作区用「条件 source」：构建过才加载，未构建时不报错。
# 不能直接删掉这行——否则新开的 shell 只有 /opt/ros/noetic 环境，
# rospack 找不到工作区里的包，roslaunch 会报 RLException。
RUN echo "source /opt/ros/noetic/setup.bash" >> $HOME/.bashrc && \
    echo '[ -f $HOME/catkin_ws/devel/setup.bash ] && source $HOME/catkin_ws/devel/setup.bash' >> $HOME/.bashrc && \
    echo 'export PS1="\[\033[01;36m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> $HOME/.bashrc && \
    echo "export HUSKY_LMS1XX_ENABLED=1" >> $HOME/.bashrc && \
    echo 'alias depcheck="rosdep check --from-paths ~/catkin_ws/src --ignore-src"' >> $HOME/.bashrc && \
    echo 'alias depinstall="rosdep install --from-paths ~/catkin_ws/src --ignore-src -r -y"' >> $HOME/.bashrc

# Variables d'environnement pour le support GUI
ENV QT_X11_NO_MITSHM=1
ENV LIBGL_ALWAYS_INDIRECT=0

WORKDIR $HOME
