const app = document.getElementById('app');
const nodesRoot = document.getElementById('nodes');
const linesRoot = document.getElementById('connections');
const pointsCounter = document.getElementById('pointsCounter');
const skillName = document.getElementById('skillName');
const skillDescription = document.getElementById('skillDescription');

let skills = {};
let player = { skillPoints: 0, skills: {} };
let activeCategory = null;
let renderedPositions = {};
let categoryNodes = {};
let anchors = {
    left: { x: 0.36, y: 0.62, visible: false },
    right: { x: 0.64, y: 0.62, visible: false }
};

const CATEGORY_TITLES = {
    combat: 'Bijatyka',
    gathering: 'Zbieractwo',
    crafting: 'Rzemiosło',
    medical: 'Medycyna',
    other: 'Inne'
};

const CATEGORY_HAND = {
    combat: 'right',
    gathering: 'left',
    crafting: 'left',
    medical: 'right',
    other: 'right'
};

const getResourceName = () => {
    try {
        return GetParentResourceName();
    } catch (_) {
        return 'horizon-skill-tree';
    }
};

const postNui = (endpoint, payload = {}) => fetch(`https://${getResourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
});

const isUnlocked = (skillId) => Boolean(player.skills && player.skills[skillId]);

const canUnlock = (skill) => {
    if (isUnlocked(skill.id)) return false;
    if (player.skillPoints < skill.cost) return false;
    if (!skill.requirement) return true;
    return isUnlocked(skill.requirement);
};

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

const normalizeAnchor = (anchor, fallbackX, fallbackY) => ({
    x: clamp(Number(anchor?.x) || fallbackX, 0.08, 0.92),
    y: clamp(Number(anchor?.y) || fallbackY, 0.2, 0.85),
    visible: Boolean(anchor?.visible)
});

const categoryName = (category) => CATEGORY_TITLES[category] || category || CATEGORY_TITLES.other;

const getCategoryEntries = () => {
    const map = {};

    Object.values(skills).forEach((skill) => {
        const category = skill.category || 'other';
        if (!map[category]) {
            map[category] = { id: category, skills: [] };
        }
        map[category].skills.push(skill);
    });

    return Object.values(map).sort((a, b) => categoryName(a.id).localeCompare(categoryName(b.id), 'pl'));
};

const getEntryAnchor = (entry) => {
    const handKey = CATEGORY_HAND[entry.id] || 'right';
    return {
        hand: handKey,
        anchor: anchors[handKey]
    };
};

const updateDetails = (skill) => {
    const requirementText = skill.requirement ? `Wymaga: ${skills[skill.requirement]?.name || skill.requirement}` : 'Wymagań brak';
    skillName.textContent = skill.name;
    skillDescription.textContent = `${skill.description} | Koszt: ${skill.cost} pkt | ${requirementText}`;
};

const updateCategoryDetails = (entry) => {
    skillName.textContent = categoryName(entry.id);
    skillDescription.textContent = activeCategory === entry.id
        ? 'Kategoria rozwinięta. Kliknij ponownie, aby zwinąć.'
        : 'Kliknij, aby rozwinąć drzewko tej kategorii.';
};

const createLine = (x1, y1, x2, y2, extraClass = '') => {
    const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    line.setAttribute('class', `connection ${extraClass}`.trim());
    line.setAttribute('x1', String(x1));
    line.setAttribute('y1', String(y1));
    line.setAttribute('x2', String(x2));
    line.setAttribute('y2', String(y2));
    return line;
};

const drawConnections = () => {
    linesRoot.innerHTML = '';

    const frameRect = nodesRoot.getBoundingClientRect();
    if (!frameRect.width || !frameRect.height) return;

    if (!activeCategory) {
        Object.values(categoryNodes).forEach((entry) => {
            const handAnchor = anchors[entry.hand];
            if (!handAnchor) return;

            linesRoot.appendChild(createLine(
                handAnchor.x * frameRect.width,
                handAnchor.y * frameRect.height,
                entry.x * frameRect.width,
                entry.y * frameRect.height,
                'hand-link'
            ));
        });
        return;
    }

    Object.values(renderedPositions).forEach((nodePosition) => {
        if (nodePosition.root) {
            const handAnchor = anchors[nodePosition.hand];
            if (!handAnchor) return;

            linesRoot.appendChild(createLine(
                handAnchor.x * frameRect.width,
                handAnchor.y * frameRect.height,
                nodePosition.x * frameRect.width,
                nodePosition.y * frameRect.height,
                isUnlocked(nodePosition.id) ? 'active hand-link' : 'hand-link'
            ));
            return;
        }

        if (!nodePosition.requirement || !renderedPositions[nodePosition.requirement]) return;

        const parent = renderedPositions[nodePosition.requirement];
        linesRoot.appendChild(createLine(
            parent.x * frameRect.width,
            parent.y * frameRect.height,
            nodePosition.x * frameRect.width,
            nodePosition.y * frameRect.height,
            isUnlocked(nodePosition.id) ? 'active' : ''
        ));
    });
};

const createNode = (label, x, y, color, extraClass, delayStep = 0) => {
    const node = document.createElement('button');
    node.type = 'button';
    node.className = `skill-node ${extraClass}`.trim();
    node.dataset.label = label;
    node.style.left = `${x * 100}%`;
    node.style.top = `${y * 100}%`;
    node.style.setProperty('--node-color', color || '#59f4ff');
    node.style.setProperty('--node-delay', `${delayStep * 60}ms`);
    return node;
};

const drawCategoryNodes = (entries) => {
    const byHand = { left: [], right: [] };
    entries.forEach((entry) => {
        const hand = CATEGORY_HAND[entry.id] || 'right';
        byHand[hand].push(entry);
    });

    categoryNodes = {};

    ['left', 'right'].forEach((hand) => {
        const handEntries = byHand[hand];
        handEntries.forEach((entry, index) => {
            const spread = (index - (handEntries.length - 1) / 2) * 0.12;
            const x = clamp(anchors[hand].x + (hand === 'left' ? 0.16 : -0.16), 0.14, 0.86);
            const y = clamp(anchors[hand].y + spread, 0.15, 0.86);
            const color = entry.skills[0]?.color || '#59f4ff';
            const node = createNode(categoryName(entry.id), x, y, color, 'category-node available', index);

            const content = document.createElement('span');
            content.className = 'diamond-content';
            content.textContent = 'OTWÓRZ';
            node.appendChild(content);

            node.addEventListener('mouseenter', () => updateCategoryDetails(entry));
            node.addEventListener('click', () => {
                activeCategory = entry.id;
                updateCategoryDetails(entry);
                drawNodes();
            });

            categoryNodes[entry.id] = { x, y, hand };
            nodesRoot.appendChild(node);
        });
    });
};

const drawExpandedCategory = (entry) => {
    const { hand, anchor } = getEntryAnchor(entry);
    const categorySkills = entry.skills;
    const categorySet = new Set(categorySkills.map((skill) => skill.id));
    const depthMemo = {};

    const getDepth = (skill) => {
        if (depthMemo[skill.id] !== undefined) return depthMemo[skill.id];
        if (!skill.requirement || !categorySet.has(skill.requirement)) {
            depthMemo[skill.id] = 0;
            return 0;
        }

        const parent = skills[skill.requirement];
        const depth = parent ? getDepth(parent) + 1 : 0;
        depthMemo[skill.id] = depth;
        return depth;
    };

    const depthGroups = {};
    categorySkills.forEach((skill) => {
        const depth = getDepth(skill);
        if (!depthGroups[depth]) depthGroups[depth] = [];
        depthGroups[depth].push(skill);
    });

    renderedPositions = {};

    Object.keys(depthGroups).map(Number).sort((a, b) => a - b).forEach((depth) => {
        const group = depthGroups[depth].sort((a, b) => a.name.localeCompare(b.name, 'pl'));

        group.forEach((skill, index) => {
            const offsetY = (index - (group.length - 1) / 2) * 0.15;
            const direction = hand === 'left' ? 1 : -1;
            const x = clamp(anchor.x + direction * (0.12 + depth * 0.14), 0.08, 0.92);
            const y = clamp(anchor.y + offsetY, 0.12, 0.88);
            const classes = ['tree-node'];

            if (isUnlocked(skill.id)) {
                classes.push('unlocked');
            } else if (canUnlock(skill)) {
                classes.push('available');
            }

            const node = createNode(skill.name, x, y, skill.color, classes.join(' '), depth + index);
            const content = document.createElement('span');
            content.className = 'diamond-content';
            content.textContent = skill.cost;
            node.appendChild(content);

            node.addEventListener('mouseenter', () => updateDetails(skill));
            node.addEventListener('click', () => {
                updateDetails(skill);
                if (canUnlock(skill)) {
                    postNui('purchaseSkill', { skillId: skill.id });
                }
            });

            renderedPositions[skill.id] = {
                id: skill.id,
                requirement: skill.requirement,
                x,
                y,
                hand,
                root: !skill.requirement || !categorySet.has(skill.requirement)
            };

            nodesRoot.appendChild(node);
        });
    });

    const categoryNode = createNode(categoryName(entry.id), anchor.x, anchor.y, categorySkills[0]?.color, 'category-node opened', 0);
    const categoryContent = document.createElement('span');
    categoryContent.className = 'diamond-content';
    categoryContent.textContent = 'WRÓĆ';
    categoryNode.appendChild(categoryContent);
    categoryNode.addEventListener('mouseenter', () => updateCategoryDetails(entry));
    categoryNode.addEventListener('click', () => {
        activeCategory = null;
        drawNodes();
    });
    nodesRoot.appendChild(categoryNode);
};

const drawNodes = () => {
    nodesRoot.innerHTML = '';
    pointsCounter.textContent = `${player.skillPoints || 0} point`;
    renderedPositions = {};
    categoryNodes = {};

    const entries = getCategoryEntries();
    if (!activeCategory || !entries.find((entry) => entry.id === activeCategory)) {
        activeCategory = null;
        drawCategoryNodes(entries);
    } else {
        const selected = entries.find((entry) => entry.id === activeCategory);
        drawExpandedCategory(selected);
    }

    drawConnections();
};

window.addEventListener('resize', drawConnections);

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;

    if (data.action === 'open') {
        app.classList.remove('hidden');
        return;
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
        return;
    }

    if (data.action === 'setData') {
        skills = data.skills || {};
        player = data.player || { skillPoints: 0, skills: {} };
        activeCategory = null;
        drawNodes();
        return;
    }

    if (data.action === 'setPlayerData') {
        player = data.player || player;
        drawNodes();
        return;
    }

    if (data.action === 'setAnchors') {
        anchors.left = normalizeAnchor(data.anchors?.left, 0.34, 0.62);
        anchors.right = normalizeAnchor(data.anchors?.right, 0.66, 0.62);
        if (!app.classList.contains('hidden')) {
            drawNodes();
        }
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        postNui('close');
    }

    if (event.key === 'Enter') {
        const selected = document.querySelector('.skill-node.available');
        if (selected) selected.click();
    }
});
