const app = document.getElementById('app');
const nodesRoot = document.getElementById('nodes');
const linesRoot = document.getElementById('connections');
const pointsCounter = document.getElementById('pointsCounter');
const skillName = document.getElementById('skillName');
const skillDescription = document.getElementById('skillDescription');
const skillMeta = document.getElementById('skillMeta');
const treeBackButton = document.getElementById('treeBackButton');

let skills = {};
let player = { skillPoints: 0, skills: {} };
let activeCategory = null;
let renderedPositions = {};
let categoryNodes = {};
let handAnchors = {
    left: { x: 0, y: 0, visible: false },
    right: { x: 0, y: 0, visible: false }
};

const CATEGORY_TITLES = {
    combat: 'Bijatyka',
    movement: 'Nogi / Stamina',
    strength: 'Siła',
    underwater: 'Buzia / Pod wodą',
    driving: 'Jazda',
    gathering: 'Zbieractwo',
    crafting: 'Rzemiosło',
    medical: 'Medycyna',
    other: 'Inne'
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
const categoryName = (category) => CATEGORY_TITLES[category] || category || CATEGORY_TITLES.other;

const setMeta = (items) => {
    skillMeta.innerHTML = '';
    items.forEach((item) => {
        const row = document.createElement('span');
        row.textContent = item;
        skillMeta.appendChild(row);
    });
};

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

const getSkillPosition = (skill, fallbackX = 50, fallbackY = 52) => ({
    x: clamp((Number(skill?.x) || fallbackX) / 100, 0.12, 0.88),
    y: clamp((Number(skill?.y) || fallbackY) / 100, 0.12, 0.88)
});

const getCategoryRootSkill = (entry) => {
    const skillIds = new Set(entry.skills.map((skill) => skill.id));
    return entry.skills.find((skill) => !skill.requirement || !skillIds.has(skill.requirement)) || entry.skills[0];
};

const updateDetails = (skill) => {
    const requirementText = skill.requirement ? `Wymaga: ${skills[skill.requirement]?.name || skill.requirement}` : 'Wymagań brak';
    const statusText = isUnlocked(skill.id)
        ? 'Status: odblokowano'
        : canUnlock(skill)
            ? 'Status: gotowe do zakupu'
            : 'Status: zablokowane';

    skillName.textContent = skill.name;
    skillDescription.textContent = skill.description;
    setMeta([
        `Koszt: ${skill.cost} pkt`,
        requirementText,
        statusText
    ]);
};

const updateCategoryDetails = (entry) => {
    skillName.textContent = categoryName(entry.id);
    skillDescription.textContent = activeCategory === entry.id
        ? 'Kategoria rozwinięta. Użyj przycisku w lewym górnym rogu, aby wrócić do wszystkich kategorii.'
        : 'Kliknij kategorię, aby zobaczyć konkretne skille na sylwetce postaci.';
    setMeta([
        `Umiejętności: ${entry.skills.length}`,
        'Koszt wejścia: zależny od skilla',
        activeCategory === entry.id ? 'Status: podgląd aktywny' : 'Status: gotowe do otwarcia'
    ]);
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

const parseAnchor = (anchor) => ({
    x: clamp(Number(anchor?.x) || 0, 0, 1),
    y: clamp(Number(anchor?.y) || 0, 0, 1),
    visible: Boolean(anchor?.visible)
});

const getActiveLinkTarget = () => {
    if (activeCategory) {
        const selectedCategory = getCategoryEntries().find((entry) => entry.id === activeCategory);
        if (selectedCategory) {
            const rootSkill = getCategoryRootSkill(selectedCategory);
            const rootPosition = renderedPositions[rootSkill.id] || getSkillPosition(rootSkill);
            return { x: rootPosition.x, y: rootPosition.y };
        }
    }

    const categoryPoints = Object.values(categoryNodes);
    if (categoryPoints.length > 0) {
        return categoryPoints[0];
    }

    return null;
};

const drawHandLink = (frameRect) => {
    const anchor = handAnchors.left;
    if (!anchor?.visible) return;

    const target = getActiveLinkTarget();
    if (!target) return;

    const anchorX = clamp((anchor.x * window.innerWidth) - frameRect.left, 0, frameRect.width);
    const anchorY = clamp((anchor.y * window.innerHeight) - frameRect.top, 0, frameRect.height);

    linesRoot.appendChild(createLine(
        anchorX,
        anchorY,
        target.x * frameRect.width,
        target.y * frameRect.height,
        'hand-link'
    ));
};

const drawConnections = () => {
    linesRoot.innerHTML = '';

    const frameRect = nodesRoot.getBoundingClientRect();
    if (!frameRect.width || !frameRect.height) return;

    if (activeCategory) {
        Object.values(renderedPositions).forEach((nodePosition) => {
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
    }

    drawHandLink(frameRect);
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

const setNodeContent = (node, stateLabel, valueLabel) => {
    const content = document.createElement('span');
    content.className = 'diamond-content';

    const state = document.createElement('span');
    state.className = 'node-state';
    state.textContent = stateLabel;

    const value = document.createElement('span');
    value.className = 'node-value';
    value.textContent = valueLabel;

    content.appendChild(state);
    content.appendChild(value);
    node.appendChild(content);
};

const drawCategoryNodes = (entries) => {
    categoryNodes = {};

    entries.forEach((entry, index) => {
        const rootSkill = getCategoryRootSkill(entry);
        const { x, y } = getSkillPosition(rootSkill);
        const color = rootSkill?.color || entry.skills[0]?.color || '#59f4ff';
        const node = createNode(categoryName(entry.id), x, y, color, 'category-node available', index);

        setNodeContent(node, 'KATEGORIA', 'OTWÓRZ');

        node.addEventListener('mouseenter', () => updateCategoryDetails(entry));
        node.addEventListener('click', () => {
            activeCategory = entry.id;
            drawNodes();
        });

        categoryNodes[entry.id] = { x, y };
        nodesRoot.appendChild(node);
    });
};

const drawExpandedCategory = (entry) => {
    renderedPositions = {};

    entry.skills
        .slice()
        .sort((a, b) => (Number(a.y) - Number(b.y)) || a.name.localeCompare(b.name, 'pl'))
        .forEach((skill, index) => {
            const { x, y } = getSkillPosition(skill);
            const classes = ['tree-node'];

            if (isUnlocked(skill.id)) {
                classes.push('unlocked');
            } else if (canUnlock(skill)) {
                classes.push('available');
            } else {
                classes.push('locked');
            }

            const node = createNode(skill.name, x, y, skill.color, classes.join(' '), index);
            setNodeContent(
                node,
                isUnlocked(skill.id) ? 'ODBL.' : canUnlock(skill) ? 'KUP' : 'LOCK',
                String(skill.cost)
            );

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
                y
            };

            nodesRoot.appendChild(node);
        });
};

const drawNodes = () => {
    nodesRoot.innerHTML = '';
    linesRoot.innerHTML = '';
    pointsCounter.textContent = `${player.skillPoints || 0} pkt`;
    renderedPositions = {};
    categoryNodes = {};

    const entries = getCategoryEntries();
    if (!activeCategory || !entries.find((entry) => entry.id === activeCategory)) {
        activeCategory = null;
        treeBackButton.classList.add('hidden');
        drawCategoryNodes(entries);
    } else {
        const selected = entries.find((entry) => entry.id === activeCategory);
        treeBackButton.classList.remove('hidden');
        drawExpandedCategory(selected);
        updateCategoryDetails(selected);
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
        handAnchors.left.visible = false;
        handAnchors.right.visible = false;
        drawConnections();
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
        handAnchors.left = parseAnchor(data.anchors?.left);
        handAnchors.right = parseAnchor(data.anchors?.right);
        drawConnections();
        return;
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

treeBackButton.addEventListener('click', () => {
    activeCategory = null;
    drawNodes();
});
