from graphviz import Digraph

def create_architecture_diagram():
    dot = Digraph('DT_Architecture', comment='Digital Twin System Framework')
    
    # 设置全局属性：字体、方向（自底向上）、样条曲线
    dot.attr(rankdir='BT', splines='ortho', fontname='Arial')
    dot.attr('node', shape='box', style='filled', fillcolor='white', fontname='Arial')

    # --- 1. Physical Shopfloor Layer (物理车间层) ---
    with dot.subgraph(name='cluster_physical') as c:
        c.attr(label='Layer 1: Physical Shopfloor (ISO 23247)', color='lightgrey', style='filled', fillcolor='#E8E8E8')
        c.node('Robots', 'Swarm Robotic System\n(4x 6-DOF Manipulators)', shape='component', fillcolor='#B0C4DE')
        c.node('Sensors', 'Heterogeneous Sensors\n(Laser/Arc/Vision)', shape='ellipse', fillcolor='#F0E68C')
        c.node('Component', 'Large-Scale Component\n(Target Workpiece)', shape='folder', fillcolor='#D3D3D3')
        
        # 物理层内部连接
        c.edge('Sensors', 'Robots', style='dashed')
        c.edge('Robots', 'Component', label='Welding Action')

    # --- 2. Data Interaction Layer (数据交互层) ---
    with dot.subgraph(name='cluster_data') as c:
        c.attr(label='Layer 2: Data Interaction', color='lightblue', style='filled', fillcolor='#E0FFFF')
        c.node('OPC', 'OPC UA Server\n(Real-time Protocol)', shape='cylinder', fillcolor='#87CEEB')
        c.node('DB', 'Digital Thread DB\n(History Data)', shape='cylinder', fillcolor='#87CEEB')

    # --- 3. Cyber-Physical Computation Layer (计算层 - 核心创新) ---
    with dot.subgraph(name='cluster_cyber') as c:
        c.attr(label='Layer 3: Cyber-Physical Computation (Core Algorithms)', color='orange', style='filled', fillcolor='#FFFACD')
        
        # 模块 A: Modeling
        c.node('Model', 'Module A: Modeling\n(Feature-Aware Simplification)', style='rounded,filled', fillcolor='#FFB6C1')
        
        # 模块 B: Scheduling
        c.node('Schedule', 'Module B: Decision\n(Hybrid PSO Task Allocation)', style='rounded,filled', fillcolor='#98FB98')
        
        # 模块 C: Planning
        c.node('Plan', 'Module C: Control\n(Goal-Biased RRT Planning)', style='rounded,filled', fillcolor='#DDA0DD')

    # --- 层间连接 (Data Flow) ---
    
    # 上行数据 (Upstream): 物理 -> OPC -> 计算
    dot.edge('Robots', 'OPC', label='Joint Angles q', color='blue')
    dot.edge('Sensors', 'OPC', label='Point Cloud', color='blue')
    dot.edge('OPC', 'Model', label='Sync Data', color='blue')
    dot.edge('OPC', 'Schedule', label='Task Status', color='blue')
    
    # 下行数据 (Downstream): 计算 -> OPC -> 物理
    dot.edge('Schedule', 'OPC', label='Task Sequence', color='darkgreen')
    dot.edge('Plan', 'OPC', label='Collision-Free Path', color='darkgreen')
    dot.edge('OPC', 'Robots', label='Execution Cmd', color='darkgreen')

    # 模块间连接
    dot.edge('Model', 'Plan', label='Environment Map')
    dot.edge('Schedule', 'Plan', label='Target Point')

    # --- 闭环反馈 (Feedback Loop) ---
    # 为了强调闭环，画一条从 Plan 回到 Model 的虚线，或者是从物理层反馈回来的大循环
    # 这里用一条显眼的红色虚线表示偏差反馈
    dot.edge('Robots', 'Plan', label='Deviation Feedback\n(Re-planning Trigger)', color='red', style='dashed', constraint='false')

    # 保存并渲染
    dot.render('architecture_diagram', view=True, format='png')
    print("架构图已生成: architecture_diagram.png")

if __name__ == '__main__':
    create_architecture_diagram()