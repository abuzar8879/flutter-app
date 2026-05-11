const { getValue, nowIso, pushChild, setValue } = require('../../db/rtdb');

const STATUS_TTL_MS = 24 * 60 * 60 * 1000;

function isActiveStatus(status) {
  const createdAt = Date.parse(status?.createdAt ?? '');
  return Number.isFinite(createdAt) && Date.now() - createdAt < STATUS_TTL_MS;
}

function mapStatus(status, user) {
  return {
    id: String(status.id),
    userId: String(status.userId),
    userName: user?.name ?? status.userName ?? 'Unknown user',
    text: status.text,
    createdAt: status.createdAt,
    user: user
      ? {
          id: String(user.id),
          name: user.name,
          email: user.email,
          avatarPath: user.avatarPath ?? null,
        }
      : null,
  };
}

async function createStatus(user, text) {
  const timestamp = nowIso();
  const { key: statusId } = await pushChild('/statuses', {});
  const status = {
    id: statusId,
    userId: String(user.id),
    userName: user.name,
    text,
    createdAt: timestamp,
  };

  await setValue(`/statuses/${statusId}`, status);
  return mapStatus(status, user);
}

async function findActiveStatuses() {
  const statuses = (await getValue('/statuses')) ?? {};
  const users = (await getValue('/users')) ?? {};

  return Object.values(statuses)
    .filter(isActiveStatus)
    .sort((a, b) => String(b.createdAt ?? '').localeCompare(String(a.createdAt ?? '')))
    .map((status) => mapStatus(status, users[status.userId]));
}

module.exports = {
  createStatus,
  findActiveStatuses,
};
