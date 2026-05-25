const app = document.getElementById('app');
const nodesRoot = document.getElementById('nodes');
const linesRoot = document.getElementById('connections');
const pointsCounter = document.getElementById('pointsCounter');
const skillName = document.getElementById('skillName');
const skillDescription = document.getElementById('skillDescription');

let skills = {};
let player = { skillPoints: 0, skills: {} };

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

const updateDetails = (skill) => {
    const requirementText = skill.requirement ? `Wymaga: ${skills[skill.requirement]?.name || skill.requirement}` : 'Wymagań brak';
    skillName.textContent = skill.name;
    skillDescription.textContent = `${skill.description} | Koszt: ${skill.cost} pkt | ${requirementText}`;
};

const drawConnections = () => {
    linesRoot.innerHTML = '';

    const frameRect = nodesRoot.getBoundingClientRect();
    Object.values(skills).forEach((skill) => {
        if (!skill.requirement || !skills[skill.requirement]) return;

        const parent = skills[skill.requirement];
        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('class', `connection ${isUnlocked(skill.id) ? 'active' : ''}`);

        const x1 = (parent.x / 100) * frameRect.width;
        const y1 = (parent.y / 100) * frameRect.height;
        const x2 = (skill.x / 100) * frameRect.width;
        const y2 = (skill.y / 100) * frameRect.height;

        line.setAttribute('x1', String(x1));
        line.setAttribute('y1', String(y1));
        line.setAttribute('x2', String(x2));
        line.setAttribute('y2', String(y2));

        linesRoot.appendChild(line);
    });
};

const drawNodes = () => {
    nodesRoot.innerHTML = '';
    pointsCounter.textContent = `${player.skillPoints || 0} point`;

    Object.values(skills).forEach((skill) => {
        const node = document.createElement('button');
        node.type = 'button';
        node.className = 'skill-node';
        node.dataset.label = skill.name;
        node.style.left = `${skill.x}%`;
        node.style.top = `${skill.y}%`;
        node.style.setProperty('--node-color', skill.color || '#59f4ff');

        if (isUnlocked(skill.id)) {
            node.classList.add('unlocked');
        } else if (canUnlock(skill)) {
            node.classList.add('available');
        }

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

        nodesRoot.appendChild(node);
    });

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
        drawNodes();
        return;
    }

    if (data.action === 'setPlayerData') {
        player = data.player || player;
        drawNodes();
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
